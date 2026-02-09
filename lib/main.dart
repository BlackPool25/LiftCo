// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'blocs/auth_bloc.dart' as app_bloc;
import 'config/theme.dart';
import 'screens/main_shell.dart';
import 'screens/login_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'services/auth_service.dart';
import 'services/device_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  // Initialize Firebase (only on mobile/web, not during tests)
  DeviceService? deviceService;
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      deviceService = DeviceService(Supabase.instance.client);
      debugPrint('Firebase initialized successfully');
    } catch (e) {
      debugPrint('Firebase initialization skipped or failed: $e');
    }
  }
  
  runApp(LiftCoApp(deviceService: deviceService));
}

class LiftCoApp extends StatelessWidget {
  final DeviceService? deviceService;
  
  const LiftCoApp({super.key, this.deviceService});
  
  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (context) => AuthService(Supabase.instance.client),
      child: BlocProvider(
        create: (context) => app_bloc.AuthBloc(
          context.read<AuthService>(),
          deviceService: deviceService,
        )..add(app_bloc.AppStarted()),
        child: MaterialApp(
          title: 'LiftCo',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: const AppNavigator(),
        ),
      ),
    );
  }
}

class AppNavigator extends StatelessWidget {
  const AppNavigator({super.key});
  
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<app_bloc.AuthBloc, app_bloc.AuthState>(
      builder: (context, state) {
        // Show loading while checking auth status
        if (state is app_bloc.AuthInitial || state is app_bloc.AuthLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryPurple),
            ),
          );
        }
        
        // Show login screen if not authenticated
        if (state is app_bloc.Unauthenticated) {
          return const LoginScreen();
        }
        
        // Show OTP verification screen
        if (state is app_bloc.OTPSent) {
          return const LoginScreen();
        }
        
        // Show magic link sent confirmation screen
        if (state is app_bloc.MagicLinkSent) {
          return LoginScreen(magicLinkEmail: state.email);
        }
        
        // Show profile setup if profile incomplete
        if (state is app_bloc.NeedsProfileCompletion) {
          return const ProfileSetupScreen();
        }
        
        // Show home screen if authenticated with complete profile
        if (state is app_bloc.Authenticated) {
          return MainShell(user: state.user);
        }
        
        // Show error screen
        if (state is app_bloc.AuthError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      context.read<app_bloc.AuthBloc>().add(app_bloc.AppStarted());
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Fallback
        return const LoginScreen();
      },
    );
  }
}
