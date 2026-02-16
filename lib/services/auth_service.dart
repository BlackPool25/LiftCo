// lib/services/auth_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:synchronized/synchronized.dart';
import 'supabase_service.dart';
import '../models/user.dart' as app_user;

class AuthException implements Exception {
  final String message;
  final String? code;
  AuthException(this.message, {this.code});

  @override
  String toString() => 'AuthException: $message';
}

class AuthService {
  final SupabaseClient _supabase;

  static final Lock _refreshSessionLock = Lock();
  static Future<Session?>? _refreshSessionFuture;

  static DateTime? _missingRefreshTokenSeenAt;
  static const Duration _missingRefreshTokenCooldown = Duration(minutes: 5);

  bool _isMissingRefreshTokenError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('no refresh token') ||
        text.contains('authsessionmissingexception') ||
        text.contains('refresh token') && text.contains('missing');
  }

  static const _kCachedProfileAuthUid = 'cached_profile_auth_uid';
  static const _kCachedProfileJson = 'cached_profile_json';
  static const _kCachedProfileComplete = 'cached_profile_complete';
  static const _kCachedProfileUpdatedAt = 'cached_profile_updated_at';

  AuthService(this._supabase);

  Future<Session?> refreshSessionLocked() {
    if (_missingRefreshTokenSeenAt != null &&
        DateTime.now().difference(_missingRefreshTokenSeenAt!) <
            _missingRefreshTokenCooldown) {
      return Future.value(null);
    }

    return _refreshSessionLock.synchronized(() {
      _refreshSessionFuture ??= _supabase.auth
          .refreshSession()
          .then((response) => response.session)
          .catchError((e, _) {
            if (_isMissingRefreshTokenError(e)) {
              _missingRefreshTokenSeenAt = DateTime.now();
            }
            debugPrint('Auth refreshSession failed: $e');
            return null;
          })
          .whenComplete(() {
            _refreshSessionFuture = null;
          });
      return _refreshSessionFuture!;
    });
  }

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<void> _cacheUserProfile(app_user.User user) async {
    final authUser = currentAuthUser;
    if (authUser == null) return;

    final prefs = await _prefs();
    await prefs.setString(_kCachedProfileAuthUid, authUser.id);
    await prefs.setString(_kCachedProfileJson, jsonEncode(user.toJson()));
    await prefs.setBool(_kCachedProfileComplete, user.isProfileComplete);
    await prefs.setString(
      _kCachedProfileUpdatedAt,
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> clearCachedProfile() async {
    final prefs = await _prefs();
    await prefs.remove(_kCachedProfileAuthUid);
    await prefs.remove(_kCachedProfileJson);
    await prefs.remove(_kCachedProfileComplete);
    await prefs.remove(_kCachedProfileUpdatedAt);
  }

  Future<app_user.User?> getCachedUserProfile() async {
    final authUser = currentAuthUser;
    if (authUser == null) return null;

    final prefs = await _prefs();
    final cachedAuthUid = prefs.getString(_kCachedProfileAuthUid);
    if (cachedAuthUid == null || cachedAuthUid != authUser.id) {
      return null;
    }

    final raw = prefs.getString(_kCachedProfileJson);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return app_user.User.fromJson(decoded);
    } catch (e) {
      debugPrint('Failed to decode cached profile: $e');
      return null;
    }
  }

  /// Fetch profile from server (Edge Function first), updating local cache on success.
  Future<app_user.User?> fetchUserProfileFromServer() async {
    final authUser = currentAuthUser;
    if (authUser == null) return null;

    try {
      final api = SupabaseService(_supabase);
      final response = await api.getCurrentUser();
      final userJson = response['user'];
      if (userJson is Map<String, dynamic>) {
        final user = app_user.User.fromJson(userJson);
        await _cacheUserProfile(user);
        return user;
      }
    } catch (e) {
      debugPrint('users-get-me failed: $e');
      // Fall back below.
    }

    // Fallback: direct table lookup (may be blocked by RLS for some rows).
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('auth_id', authUser.id)
          .maybeSingle();
      if (response == null) return null;
      final user = app_user.User.fromJson(response);
      await _cacheUserProfile(user);
      return user;
    } catch (e) {
      debugPrint('Direct profile lookup failed: $e');
      return null;
    }
  }

  // Get current session
  Session? get currentSession => _supabase.auth.currentSession;

  // Get current user
  User? get currentAuthUser => _supabase.auth.currentUser;

  // Check if user is authenticated
  bool get isAuthenticated => currentSession != null;

  // Auth state stream
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Send a magic link to the user's email.
  ///
  /// Note: This relies on an external browser redirect / deep link callback to
  /// complete sign-in and persist the session.
  Future<void> requestEmailMagicLink(String email) async {
    try {
      final redirectTo = kIsWeb
          ? Uri.base.origin
          : 'com.liftco.liftco://login-callback/';

      await _supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
        emailRedirectTo: redirectTo,
      );
    } on AuthException catch (e) {
      throw AuthException(e.message, code: 'auth_error');
    } catch (e) {
      throw AuthException('Failed to send magic link: $e');
    }
  }

  /// Request an Email OTP (no magic-link redirect).
  ///
  /// This avoids web callback/deeplink issues that can prevent sessions from
  /// being persisted (which breaks JWT-protected Edge Functions like chat).
  Future<void> requestEmailOtp(String email) async {
    try {
      await _supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
        // Intentionally omit emailRedirectTo so Supabase sends a 6-digit OTP
        // that we verify inside the app.
      );
    } on AuthException catch (e) {
      throw AuthException(e.message, code: 'auth_error');
    } catch (e) {
      throw AuthException('Failed to send email OTP: $e');
    }
  }

  /// Verify email OTP
  Future<AuthResponse> verifyEmailOTP(String email, String otp) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.email,
      );
      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message, code: 'auth_error');
    } catch (e) {
      throw AuthException('Invalid OTP: $e');
    }
  }

  /// Sign in with phone OTP
  Future<void> signInWithPhoneOTP(String phone) async {
    try {
      await _supabase.auth.signInWithOtp(phone: phone, shouldCreateUser: true);
    } on AuthException catch (e) {
      throw AuthException(e.message, code: 'auth_error');
    } catch (e) {
      throw AuthException('Failed to send OTP: $e');
    }
  }

  /// Verify phone OTP
  Future<AuthResponse> verifyPhoneOTP(String phone, String otp) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        phone: phone,
        token: otp,
        type: OtpType.sms,
      );
      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message, code: 'auth_error');
    } catch (e) {
      throw AuthException('Invalid OTP: $e');
    }
  }

  /// Sign in with Google OAuth
  Future<bool> signInWithGoogle() async {
    try {
      final webRedirectTo = kIsWeb ? Uri.base.origin : null;
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? webRedirectTo
            : 'com.liftco.liftco://login-callback/',
      );
      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message, code: 'auth_error');
    } catch (e) {
      throw AuthException('Google sign in failed: $e');
    }
  }

  /// Sign in with Apple OAuth
  Future<bool> signInWithApple() async {
    try {
      final webRedirectTo = kIsWeb ? Uri.base.origin : null;
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: kIsWeb ? webRedirectTo : 'com.liftco.liftco://login-callback/',
      );
      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message, code: 'auth_error');
    } catch (e) {
      throw AuthException('Apple sign in failed: $e');
    }
  }

  /// Check if user exists in database
  Future<app_user.User?> getUserProfile() async {
    return fetchUserProfileFromServer();
  }

  /// Check if user profile exists
  Future<bool> checkUserExists() async {
    try {
      final authUser = currentAuthUser;
      if (authUser == null) return false;

      final response = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', authUser.id)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Create or update user profile
  Future<app_user.User> completeProfile({
    required String name,
    required int age,
    required String gender,
    required String experienceLevel,
    required String preferredTime,
    String? currentWorkoutSplit,
    int? timeWorkingOutMonths,
    String? bio,
  }) async {
    try {
      final authUser = currentAuthUser;
      if (authUser == null) {
        throw AuthException('Not authenticated');
      }

      // Normalize phone number: treat empty strings as null for consistency
      final phoneNumber = authUser.phone?.trim();
      final email = authUser.email?.trim();
      final normalizedPhone = (phoneNumber?.isNotEmpty ?? false)
          ? phoneNumber
          : null;
      final normalizedEmail = (email?.isNotEmpty ?? false) ? email : null;

      if (normalizedEmail == null && normalizedPhone == null) {
        throw AuthException('Profile requires at least email or phone number');
      }

      final userData = {
        'name': name,
        'auth_id': authUser.id,
        'email': normalizedEmail,
        'phone_number': normalizedPhone,
        'age': age,
        'gender': gender,
        'experience_level': experienceLevel,
        'preferred_time': preferredTime,
        'current_workout_split': currentWorkoutSplit,
        'time_working_out_months': timeWorkingOutMonths,
        'bio': bio,
        'reputation_score': 100,
      };

        debugPrint('Saving user profile with data: $userData');

      Map<String, dynamic>? existingProfile = await _supabase
          .from('users')
          .select('id')
          .eq('auth_id', authUser.id)
          .maybeSingle();

      final response = existingProfile != null
          ? await _supabase
                .from('users')
                .update({...userData, 'updated_at': DateTime.now().toIso8601String()})
                .eq('id', existingProfile['id'])
                .select()
                .single()
          : await _supabase.from('users').insert(userData).select().single();

      debugPrint('Profile saved successfully: $response');
      final user = app_user.User.fromJson(response);
      await _cacheUserProfile(user);
      return user;
    } on PostgrestException catch (e) {
      throw AuthException('Database error: ${e.message}', code: e.code);
    } catch (e) {
      throw AuthException('Failed to complete profile: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      await clearCachedProfile();
    } catch (e) {
      throw AuthException('Failed to sign out: $e');
    }
  }
}
