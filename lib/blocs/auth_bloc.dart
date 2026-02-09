// lib/blocs/auth_bloc.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
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
    name, age, gender, experienceLevel, preferredTime,
    currentWorkoutSplit, timeWorkingOutMonths, bio,
  ];
}

class SignOutRequested extends AuthEvent {}

class SupabaseAuthStateChanged extends AuthEvent {
  final dynamic authState;
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
    _authService.authStateChanges.listen((authState) {
      add(SupabaseAuthStateChanged(authState));
    });
  }
  
  /// Register device for push notifications
  Future<void> _registerDevice() async {
    if (_deviceService != null && _authService.currentAuthUser != null) {
      try {
        await _deviceService.registerDevice(_authService.currentAuthUser!.id);
      } catch (e) {
        debugPrint('Failed to register device: $e');
      }
    }
  }
  
  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    
    try {
      if (_authService.isAuthenticated) {
        final user = await _authService.getUserProfile();
        if (user != null) {
          if (user.isProfileComplete) {
            await _registerDevice();  // Register device on successful auth
            emit(Authenticated(user));
          } else {
            emit(NeedsProfileCompletion(
              email: user.email,
              phone: user.phoneNumber,
            ));
          }
        } else {
          emit(NeedsProfileCompletion(
            email: _authService.currentAuthUser?.email,
            phone: _authService.currentAuthUser?.phone,
          ));
        }
      } else {
        emit(const Unauthenticated());
      }
    } catch (e) {
      emit(Unauthenticated(errorMessage: e.toString()));
    }
  }
  
  Future<void> _onSignInWithEmail(
    SignInWithEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      await _authService.signInWithEmailMagicLink(event.email);
      debugPrint('Magic link sent successfully, emitting MagicLinkSent state');
      emit(MagicLinkSent(email: event.email));
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
      
      // Register device for push notifications after profile completion
      await _registerDevice();
      
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
  
  /// Deactivate device before signing out
  Future<void> _deactivateDevice() async {
    if (_deviceService != null && _authService.currentAuthUser != null) {
      try {
        await _deviceService.deactivateDevice(_authService.currentAuthUser!.id);
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
      // Deactivate device before signing out
      await _deactivateDevice();
      
      await _authService.signOut();
      emit(const Unauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
  
  Future<void> _onAuthStateChanged(
    SupabaseAuthStateChanged event,
    Emitter<AuthState> emit,
  ) async {
    final session = event.authState.session;
    
    if (session == null) {
      emit(const Unauthenticated());
      return;
    }
    
    // For OAuth, check if user profile exists
    try {
      final exists = await _authService.checkUserExists();
      if (exists) {
        final user = await _authService.getUserProfile();
        if (user != null && user.isProfileComplete) {
          // Register device for push notifications on successful auth
          await _registerDevice();
          emit(Authenticated(user));
        } else {
          emit(NeedsProfileCompletion(
            email: session.user.email,
            phone: session.user.phone,
          ));
        }
      } else {
        emit(NeedsProfileCompletion(
          email: session.user.email,
          phone: session.user.phone,
        ));
      }
    } catch (e) {
      emit(NeedsProfileCompletion(
        email: session.user.email,
        phone: session.user.phone,
      ));
    }
  }
}
