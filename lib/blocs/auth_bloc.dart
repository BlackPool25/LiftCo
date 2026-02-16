// lib/blocs/auth_bloc.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../models/user.dart' as app_user;
import '../services/auth_service.dart';
import '../services/device_service.dart';

// Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {}

class SignInWithEmailRequested extends AuthEvent {
  final String email;
  const SignInWithEmailRequested(this.email);

  @override
  List<Object?> get props => [email];
}

class VerifyEmailOTPRequested extends AuthEvent {
  final String email;
  final String otp;
  const VerifyEmailOTPRequested(this.email, this.otp);

  @override
  List<Object?> get props => [email, otp];
}

class SignInWithPhoneRequested extends AuthEvent {
  final String phone;
  const SignInWithPhoneRequested(this.phone);

  @override
  List<Object?> get props => [phone];
}

class VerifyPhoneOTPRequested extends AuthEvent {
  final String phone;
  final String otp;
  const VerifyPhoneOTPRequested(this.phone, this.otp);

  @override
  List<Object?> get props => [phone, otp];
}

class SignInWithGoogleRequested extends AuthEvent {}

class SignInWithAppleRequested extends AuthEvent {}

class CompleteProfileRequested extends AuthEvent {
  final String name;
  final int age;
  final String gender;
  final String experienceLevel;
  final String preferredTime;
  final String? currentWorkoutSplit;
  final int? timeWorkingOutMonths;
  final String? bio;

  const CompleteProfileRequested({
    required this.name,
    required this.age,
    required this.gender,
    required this.experienceLevel,
    required this.preferredTime,
    this.currentWorkoutSplit,
    this.timeWorkingOutMonths,
    this.bio,
  });

  @override
  List<Object?> get props => [
    name,
    age,
    gender,
    experienceLevel,
    preferredTime,
    currentWorkoutSplit,
    timeWorkingOutMonths,
    bio,
  ];
}

class SignOutRequested extends AuthEvent {}

class SupabaseAuthStateChanged extends AuthEvent {
  final sb.AuthState authState;
  const SupabaseAuthStateChanged(this.authState);

  @override
  List<Object?> get props => [authState];
}

// States
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Unauthenticated extends AuthState {
  final String? errorMessage;
  const Unauthenticated({this.errorMessage});

  @override
  List<Object?> get props => [errorMessage];
}

class OTPSent extends AuthState {
  final String emailOrPhone;
  final bool isEmail;
  const OTPSent({required this.emailOrPhone, required this.isEmail});

  @override
  List<Object?> get props => [emailOrPhone, isEmail];
}

class MagicLinkSent extends AuthState {
  final String email;
  const MagicLinkSent({required this.email});

  @override
  List<Object?> get props => [email];
}

class Authenticated extends AuthState {
  final app_user.User user;
  const Authenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class NeedsProfileCompletion extends AuthState {
  final String? email;
  final String? phone;
  const NeedsProfileCompletion({this.email, this.phone});

  @override
  List<Object?> get props => [email, phone];
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  final DeviceService? _deviceService;

  Timer? _authStateDebounce;
  StreamSubscription<dynamic>? _authStateSubscription;

  bool _explicitSignOutInProgress = false;

  DateTime? _firstNullSessionSeenAt;
  DateTime? _lastNullSessionRecoveryAttemptAt;
  DateTime? _lastDeviceRegisterAttemptAt;
  String? _lastDeviceRegisterUserId;

  static const Duration _nullSessionMaxGrace = Duration(minutes: 2);
  static const Duration _nullSessionRecoveryCooldown = Duration(seconds: 10);
  static const Duration _deviceRegisterCooldown = Duration(hours: 12);

  Future<app_user.User?> _fetchProfileWithRetry() async {
    // Short, bounded retries to allow backend auth_id self-heal and network jitter.
    const delays = <Duration>[
      Duration(milliseconds: 250),
      Duration(milliseconds: 500),
      Duration(milliseconds: 800),
    ];

    for (var attempt = 0; attempt < delays.length; attempt++) {
      final user = await _authService.fetchUserProfileFromServer();
      if (user != null) return user;
      await Future.delayed(delays[attempt]);
    }
    return null;
  }

  Future<void> _registerDeviceSilently() async {
    if (_deviceService == null) return;

    // Avoid hammering device registration on token refresh / repeated auth events.
    final currentAuthUser = _authService.currentAuthUser;
    final authUid = currentAuthUser?.id;
    if (authUid != null &&
        _lastDeviceRegisterUserId == authUid &&
        _lastDeviceRegisterAttemptAt != null &&
        DateTime.now().difference(_lastDeviceRegisterAttemptAt!) <
            _deviceRegisterCooldown) {
      return;
    }

    try {
      // Silent: do not re-prompt permissions from background refreshes.
      await _deviceService.registerDevice(requestPermissionIfNeeded: false);
      _lastDeviceRegisterAttemptAt = DateTime.now();
      _lastDeviceRegisterUserId = authUid;
    } catch (e) {
      debugPrint('Failed to auto-register device: $e');
    }
  }

  AuthBloc(this._authService, {DeviceService? deviceService})
    : _deviceService = deviceService,
      super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<SignInWithEmailRequested>(_onSignInWithEmail);
    on<VerifyEmailOTPRequested>(_onVerifyEmailOTP);
    on<SignInWithPhoneRequested>(_onSignInWithPhone);
    on<VerifyPhoneOTPRequested>(_onVerifyPhoneOTP);
    on<SignInWithGoogleRequested>(_onSignInWithGoogle);
    on<SignInWithAppleRequested>(_onSignInWithApple);
    on<CompleteProfileRequested>(_onCompleteProfile);
    on<SignOutRequested>(_onSignOut);
    on<SupabaseAuthStateChanged>(_onAuthStateChanged);

    // Listen to auth state changes
    _authStateSubscription = _authService.authStateChanges.listen((authState) {
      _authStateDebounce?.cancel();
      _authStateDebounce = Timer(const Duration(milliseconds: 500), () {
        add(SupabaseAuthStateChanged(authState));
      });
    });
  }

  @override
  Future<void> close() async {
    _authStateDebounce?.cancel();
    await _authStateSubscription?.cancel();
    return super.close();
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    if (!_authService.isAuthenticated) {
      emit(const Unauthenticated());
      return;
    }

    try {
      // Cache-first: if we *know* the profile is complete, avoid showing setup on cold start.
      final cached = await _authService.getCachedUserProfile();
      if (cached != null && cached.isProfileComplete) {
        emit(Authenticated(cached));
        await _registerDeviceSilently();
      }

      // Keep cache in sync: do a server refresh after a short delay.
      await Future.delayed(const Duration(milliseconds: 350));
      final fresh = await _fetchProfileWithRetry();

      if (fresh != null) {
        if (fresh.isProfileComplete) {
          emit(Authenticated(fresh));
          await _registerDeviceSilently();
        } else {
          emit(
            NeedsProfileCompletion(
              email: fresh.email,
              phone: fresh.phoneNumber,
            ),
          );
        }
        return;
      }

      // No fresh profile. If we had a cached complete profile, keep user in the app.
      if (cached != null && cached.isProfileComplete) {
        return;
      }

      // If authenticated but profile isn't resolvable, avoid incorrectly forcing setup.
      emit(const AuthError('Unable to load profile. Please try again.'));
    } catch (e) {
      // Don’t force a logout just because a refresh/profile fetch failed.
      final cached = await _authService.getCachedUserProfile();
      if (cached != null && cached.isProfileComplete) {
        debugPrint('AppStarted refresh failed; keeping cached auth state: $e');
        return;
      }
      emit(const AuthError('Unable to load profile. Please try again.'));
    }
  }

  Future<void> _onSignInWithEmail(
    SignInWithEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _authService.requestEmailOtp(event.email);
      emit(OTPSent(emailOrPhone: event.email, isEmail: true));
    } catch (e) {
      debugPrint('Magic link error: $e');
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onVerifyEmailOTP(
    VerifyEmailOTPRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _authService.verifyEmailOTP(event.email, event.otp);

      // Check if user exists
      final exists = await _authService.checkUserExists();
      if (exists) {
        final user = await _authService.getUserProfile();
        if (user != null && user.isProfileComplete) {
          emit(Authenticated(user));
        } else {
          emit(NeedsProfileCompletion(email: event.email));
        }
      } else {
        emit(NeedsProfileCompletion(email: event.email));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignInWithPhone(
    SignInWithPhoneRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _authService.signInWithPhoneOTP(event.phone);
      emit(OTPSent(emailOrPhone: event.phone, isEmail: false));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onVerifyPhoneOTP(
    VerifyPhoneOTPRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _authService.verifyPhoneOTP(event.phone, event.otp);

      // Check if user exists
      final exists = await _authService.checkUserExists();
      if (exists) {
        final user = await _authService.getUserProfile();
        if (user != null && user.isProfileComplete) {
          emit(Authenticated(user));
        } else {
          emit(NeedsProfileCompletion(phone: event.phone));
        }
      } else {
        emit(NeedsProfileCompletion(phone: event.phone));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignInWithGoogle(
    SignInWithGoogleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _authService.signInWithGoogle();
      // OAuth will trigger auth state change
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignInWithApple(
    SignInWithAppleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _authService.signInWithApple();
      // OAuth will trigger auth state change
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onCompleteProfile(
    CompleteProfileRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      debugPrint(
        'Completing profile with: name=${event.name}, age=${event.age}, gender=${event.gender}, experience=${event.experienceLevel}, time=${event.preferredTime}',
      );

      final user = await _authService.completeProfile(
        name: event.name,
        age: event.age,
        gender: event.gender,
        experienceLevel: event.experienceLevel,
        preferredTime: event.preferredTime,
        currentWorkoutSplit: event.currentWorkoutSplit,
        timeWorkingOutMonths: event.timeWorkingOutMonths,
        bio: event.bio,
      );

      debugPrint(
        'Profile completed successfully. isProfileComplete: ${user.isProfileComplete}',
      );

      emit(Authenticated(user));
      await _registerDeviceSilently();
    } catch (e) {
      debugPrint('Profile completion failed: $e');
      emit(AuthError(e.toString()));
    }
  }

  /// Deactivate device before signing out
  Future<void> _deactivateDevice() async {
    if (_deviceService != null && _authService.currentAuthUser != null) {
      try {
        await _deviceService.deactivateDevice();
      } catch (e) {
        debugPrint('Failed to deactivate device: $e');
      }
    }
  }

  Future<void> _onSignOut(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      _explicitSignOutInProgress = true;
      // Deactivate device before signing out
      await _deactivateDevice();

      await _authService.signOut();
      emit(const Unauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    } finally {
      _explicitSignOutInProgress = false;
    }
  }

  Future<void> _onAuthStateChanged(
    SupabaseAuthStateChanged event,
    Emitter<AuthState> emit,
  ) async {
    final session = event.authState.session;
    final changeEvent = event.authState.event;

    // Token refreshes are frequent during normal operation; avoid treating them
    // like a full login (profile fetch + device registration), which creates
    // request storms and can trigger 429 refresh rate limits.
    if (changeEvent == sb.AuthChangeEvent.tokenRefreshed) {
      if (state is Authenticated || state is NeedsProfileCompletion) {
        return;
      }
      // If we're still booting/loading, fall through to resolve profile.
    }

    if (session == null) {
      if (_explicitSignOutInProgress) {
        await _authService.clearCachedProfile();
        emit(const Unauthenticated());
        return;
      }

      // If Supabase explicitly reports a sign-out, respect it.
      if (changeEvent == sb.AuthChangeEvent.signedOut) {
        _firstNullSessionSeenAt = null;
        await _authService.clearCachedProfile();
        emit(const Unauthenticated());
        return;
      }

      _firstNullSessionSeenAt ??= DateTime.now();
      final nullDuration = DateTime.now().difference(_firstNullSessionSeenAt!);
      if (nullDuration > _nullSessionMaxGrace) {
        _firstNullSessionSeenAt = null;
        await _authService.clearCachedProfile();
        emit(
          const Unauthenticated(errorMessage: 'Session expired. Please sign in again.'),
        );
        return;
      }

      // Supabase can briefly report a null session during refresh/storage sync.
      // Re-check after a short delay before treating this as a real sign-out.
      await Future.delayed(const Duration(milliseconds: 800));
      if (_authService.isAuthenticated) {
        _firstNullSessionSeenAt = null;
        return;
      }

      // Attempt an explicit refresh (locked) before giving up. This avoids
      // getting stuck in an Authenticated UI state with no usable token.
      final lastAttempt = _lastNullSessionRecoveryAttemptAt;
      if (lastAttempt == null ||
          DateTime.now().difference(lastAttempt) > _nullSessionRecoveryCooldown) {
        _lastNullSessionRecoveryAttemptAt = DateTime.now();
        final refreshed = await _authService.refreshSessionLocked();
        if (refreshed != null) {
          _firstNullSessionSeenAt = null;
          return;
        }
      }

      // If we hit rate limiting during refresh, recovery can take a bit longer.
      // Give it a little more time before forcing logout.
      await Future.delayed(const Duration(milliseconds: 2200));
      if (_authService.isAuthenticated) {
        _firstNullSessionSeenAt = null;
        return;
      }

      // If we have a cached complete profile or we're currently showing an
      // authenticated UI, do not force a logout here. This is typically a
      // transient token/rehydration gap (often with refresh rate limiting).
      final cached = await _authService.getCachedUserProfile();
      final canStayInApp =
          (state is Authenticated) || (cached?.isProfileComplete ?? false);
      if (canStayInApp) {
        return;
      }

      await _authService.clearCachedProfile();
      emit(
        const Unauthenticated(errorMessage: 'Session expired. Please sign in again.'),
      );
      return;
    }

    _firstNullSessionSeenAt = null;

    // Auth changed (sign-in/refresh). Prefer cached profile for this auth user,
    // then refresh from server to avoid transient "profile not found" races.
    try {
      final cached = await _authService.getCachedUserProfile();
      if (cached != null && cached.isProfileComplete) {
        emit(Authenticated(cached));
        await _registerDeviceSilently();
      }

      final fresh = await _fetchProfileWithRetry();
      if (fresh != null && fresh.isProfileComplete) {
        emit(Authenticated(fresh));
        await _registerDeviceSilently();
        return;
      }

      // If profile exists but incomplete, route to completion.
      if (fresh != null) {
        emit(
          NeedsProfileCompletion(
            email: fresh.email ?? session.user.email,
            phone: fresh.phoneNumber ?? session.user.phone,
          ),
        );
        return;
      }

      // If we can't resolve the profile yet, keep the user in loading rather than misrouting.
      if (cached != null && cached.isProfileComplete) {
        debugPrint('Profile refresh failed, using cached');
        return;
      }
      emit(const AuthError('Unable to load profile. Please try again.'));
    } catch (_) {
      final cached = await _authService.getCachedUserProfile();
      if (cached != null && cached.isProfileComplete) {
        debugPrint('Profile refresh threw, using cached');
        return;
      }
      emit(const AuthError('Unable to load profile. Please try again.'));
    }
  }
}
