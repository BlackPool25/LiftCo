// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
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

  AuthService(this._supabase);

  // Get current session
  Session? get currentSession => _supabase.auth.currentSession;

  // Get current user
  User? get currentAuthUser => _supabase.auth.currentUser;

  // Check if user is authenticated
  bool get isAuthenticated => currentSession != null;

  // Auth state stream
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Sign in with email Magic Link
  Future<void> signInWithEmailMagicLink(String email) async {
    try {
      // Use magic link instead of OTP
      await _supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
        emailRedirectTo: kIsWeb
            ? 'http://localhost:3000'
            : 'com.liftco.liftco://login-callback/',
      );
    } on AuthException catch (e) {
      throw AuthException(e.message, code: 'auth_error');
    } catch (e) {
      throw AuthException('Failed to send magic link: $e');
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
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? 'http://localhost:3000'
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
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: kIsWeb ? null : 'com.liftco.liftco://login-callback/',
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
    try {
      final authUser = currentAuthUser;
      if (authUser == null) return null;

      final response = await _supabase
          .from('users')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      if (response == null) return null;
      return app_user.User.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  /// Check if user profile exists
  Future<bool> checkUserExists() async {
    try {
      final authUser = currentAuthUser;
      if (authUser == null) return false;

      final response = await _supabase
          .from('users')
          .select('id')
          .eq('id', authUser.id)
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

      final userData = {
        'id': authUser.id,
        'name': name,
        'email': authUser.email,
        'phone_number': (phoneNumber?.isNotEmpty ?? false) ? phoneNumber : null,
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

      final response = await _supabase
          .from('users')
          .upsert(userData, onConflict: 'id')
          .select()
          .single();

      debugPrint('Profile saved successfully: $response');
      return app_user.User.fromJson(response);
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
    } catch (e) {
      throw AuthException('Failed to sign out: $e');
    }
  }
}
