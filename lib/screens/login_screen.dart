// lib/screens/login_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../blocs/auth_bloc.dart';
import '../config/theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = 
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = 
      List.generate(6, (_) => FocusNode());
  
  bool _isEmail = true;
  bool _otpSent = false;
  String _contactInfo = '';

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _sendOTP() {
    if (_isEmail) {
      final email = _emailController.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        _showError('Please enter a valid email');
        return;
      }
      context.read<AuthBloc>().add(SignInWithEmailRequested(email));
      setState(() => _contactInfo = email);
    } else {
      String phone = _phoneController.text.trim();
      if (phone.isEmpty || phone.length < 10) {
        _showError('Please enter a valid phone number');
        return;
      }
      if (!phone.startsWith('+')) {
        phone = '+1$phone';
      }
      context.read<AuthBloc>().add(SignInWithPhoneRequested(phone));
      setState(() => _contactInfo = phone);
    }
  }

  void _verifyOTP() {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      _showError('Please enter a valid 6-digit OTP');
      return;
    }

    if (_isEmail) {
      context.read<AuthBloc>().add(VerifyEmailOTPRequested(_contactInfo, otp));
    } else {
      context.read<AuthBloc>().add(VerifyPhoneOTPRequested(_contactInfo, otp));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _signInWithGoogle() {
    context.read<AuthBloc>().add(SignInWithGoogleRequested());
  }

  void _signInWithApple() {
    context.read<AuthBloc>().add(SignInWithAppleRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is OTPSent) {
            setState(() {
              _otpSent = true;
              _isEmail = state.isEmail;
            });
          } else if (state is AuthError) {
            _showError(state.message);
            setState(() => _otpSent = false);
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              // Animated gradient background
              _buildBackground(),
              
              // Content
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 60),
                      
                      // Logo & Title
                      _buildHeader()
                          .animate()
                          .fadeIn(duration: 600.ms)
                          .slideY(begin: -0.2, end: 0),
                      
                      const SizedBox(height: 48),
                      
                      // Main content card
                      GlassCard(
                        padding: const EdgeInsets.all(28),
                        borderRadius: 28,
                        child: state is AuthLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryPurple,
                                  ),
                                ),
                              )
                            : _otpSent
                                ? _buildOTPContent()
                                : _buildLoginContent(),
                      ).animate().fadeIn(delay: 200.ms, duration: 500.ms)
                          .slideY(begin: 0.1, end: 0),
                      
                      const SizedBox(height: 32),
                      
                      // Terms text
                      if (!_otpSent)
                        Center(
                          child: Text(
                            'By continuing, you agree to our Terms & Privacy Policy',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ).animate().fadeIn(delay: 400.ms),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.surfaceGradient,
      ),
      child: Stack(
        children: [
          // Floating gradient orbs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryPurple.withValues(alpha: 0.3),
                    AppTheme.primaryPurple.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: 0, end: 30, duration: 4.seconds, curve: Curves.easeInOut),
          Positioned(
            bottom: 100,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accentCyan.withValues(alpha: 0.2),
                    AppTheme.accentCyan.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: 0, end: -20, duration: 3.seconds, curve: Curves.easeInOut),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.fitness_center_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Welcome to',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 4),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppTheme.primaryPurple, AppTheme.accentCyan],
          ).createShader(bounds),
          child: Text(
            'LiftCo',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Find your perfect gym buddy and never skip a workout again.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _buildLoginContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle between email and phone
        Row(
          children: [
            _buildToggleButton('Email', _isEmail, () {
              setState(() => _isEmail = true);
            }),
            const SizedBox(width: 12),
            _buildToggleButton('Phone', !_isEmail, () {
              setState(() => _isEmail = false);
            }),
          ],
        ),
        const SizedBox(height: 24),

        // Input field
        if (_isEmail)
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Enter your email',
              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted),
            ),
          )
        else
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: AppTheme.textPrimary),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: 'Enter your phone number',
              prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.textMuted),
              prefixText: '+1 ',
            ),
          ),
        const SizedBox(height: 24),

        // Continue button
        SizedBox(
          width: double.infinity,
          child: GradientButton(
            text: 'Continue',
            onPressed: _sendOTP,
          ),
        ),

        const SizedBox(height: 28),

        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: AppTheme.surfaceBorder)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'or continue with',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(child: Divider(color: AppTheme.surfaceBorder)),
          ],
        ),

        const SizedBox(height: 24),

        // OAuth buttons
        Row(
          children: [
            Expanded(
              child: OAuthButton(
                text: 'Google',
                icon: const FaIcon(FontAwesomeIcons.google,
                    size: 20, color: Colors.white),
                onPressed: _signInWithGoogle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OAuthButton(
                text: 'Apple',
                icon: const FaIcon(FontAwesomeIcons.apple,
                    size: 22, color: Colors.white),
                onPressed: _signInWithApple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToggleButton(String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: isActive ? AppTheme.primaryGradient : null,
            color: isActive ? null : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? Colors.transparent : AppTheme.surfaceBorder,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOTPContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button
        GestureDetector(
          onTap: () {
            setState(() {
              _otpSent = false;
              for (var c in _otpControllers) {
                c.clear();
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: AppTheme.textPrimary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Verify your ${_isEmail ? 'email' : 'phone'}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              TextSpan(
                text: _contactInfo,
                style: const TextStyle(
                  color: AppTheme.primaryPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // OTP Input boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 48,
              height: 56,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.surfaceBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.surfaceBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryPurple,
                      width: 2,
                    ),
                  ),
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  if (value.isNotEmpty && index < 5) {
                    _otpFocusNodes[index + 1].requestFocus();
                  }
                  if (value.isEmpty && index > 0) {
                    _otpFocusNodes[index - 1].requestFocus();
                  }
                  // Auto-verify when all digits entered
                  if (_otpControllers.every((c) => c.text.isNotEmpty)) {
                    _verifyOTP();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 32),

        // Verify button
        SizedBox(
          width: double.infinity,
          child: GradientButton(
            text: 'Verify',
            onPressed: _verifyOTP,
          ),
        ),
        const SizedBox(height: 16),

        // Resend
        Center(
          child: TextButton(
            onPressed: _sendOTP,
            child: Text(
              'Didn\'t receive code? Resend',
              style: TextStyle(
                color: AppTheme.accentCyan,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
