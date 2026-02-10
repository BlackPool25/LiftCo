// lib/screens/login_screen.dart
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
  /// If provided, the login screen will show the magic link sent confirmation UI
  /// with this email address displayed.
  final String? magicLinkEmail;

  const LoginScreen({super.key, this.magicLinkEmail});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isEmail = true;
  bool _otpSent = false;
  bool _magicLinkSent = false;
  String _contactInfo = '';

  @override
  void initState() {
    super.initState();
    // Initialize state from constructor parameter if provided
    if (widget.magicLinkEmail != null) {
      _magicLinkSent = true;
      _contactInfo = widget.magicLinkEmail!;
    }
  }

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
      setState(() {
        _contactInfo = email;
        _magicLinkSent = true; // Show confirmation UI immediately
      });
      context.read<AuthBloc>().add(SignInWithEmailRequested(email));
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
              _magicLinkSent = false;
              _isEmail = state.isEmail;
            });
          } else if (state is MagicLinkSent) {
            setState(() {
              _magicLinkSent = true;
              _otpSent = false;
              _contactInfo = state.email;
            });
          } else if (state is AuthError) {
            _showError(state.message);
            setState(() {
              _otpSent = false;
              _magicLinkSent = false;
            });
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
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          MediaQuery.of(context).size.height -
                          MediaQuery.of(context).padding.top -
                          MediaQuery.of(context).padding.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.04,
                        ),

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
                              child: _magicLinkSent
                                  ? _buildMagicLinkSentContent()
                                  : _otpSent
                                  ? _buildOTPContent()
                                  : state is AuthLoading
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(40),
                                        child: CircularProgressIndicator(
                                          color: AppTheme.primaryOrange,
                                        ),
                                      ),
                                    )
                                  : _buildLoginContent(),
                            )
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 500.ms)
                            .slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 32),

                        // Terms text
                        if (!_otpSent && !_magicLinkSent)
                          Center(
                            child: Text(
                              'By continuing, you agree to our Terms & Privacy Policy',
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ).animate().fadeIn(delay: 400.ms),

                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.03,
                        ),
                      ],
                    ),
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
      decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
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
              .moveY(
                begin: 0,
                end: 30,
                duration: 4.seconds,
                curve: Curves.easeInOut,
              ),
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
              .moveY(
                begin: 0,
                end: -20,
                duration: 3.seconds,
                curve: Curves.easeInOut,
              ),
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
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: AppTheme.textSecondary),
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
        // Toggle between email and phone - with smooth sliding indicator
        _buildSmoothToggle(),
        const SizedBox(height: 24),

        // Input field - Use AnimatedSwitcher for smooth transitions
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isEmail
              ? TextField(
                  key: const ValueKey('email'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: true,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Enter your email',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: AppTheme.textMuted,
                    ),
                  ),
                )
              : TextField(
                  key: const ValueKey('phone'),
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: 'Enter your phone number',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                      color: AppTheme.textMuted,
                    ),
                    prefixText: '+1 ',
                  ),
                ),
        ),
        const SizedBox(height: 24),

        // Continue button
        SizedBox(
          width: double.infinity,
          child: GradientButton(text: 'Continue', onPressed: _sendOTP),
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
                icon: const FaIcon(
                  FontAwesomeIcons.google,
                  size: 20,
                  color: Colors.white,
                ),
                onPressed: _signInWithGoogle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OAuthButton(
                text: 'Apple',
                icon: const FaIcon(
                  FontAwesomeIcons.apple,
                  size: 22,
                  color: Colors.white,
                ),
                onPressed: _signInWithApple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Smooth sliding toggle with animated indicator
  Widget _buildSmoothToggle() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final buttonWidth = availableWidth / 2;

          return Stack(
            children: [
              // Animated sliding indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: _isEmail ? 0 : buttonWidth,
                top: 0,
                bottom: 0,
                width: buttonWidth,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryOrange.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Labels (always visible, change color based on selection)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isEmail = true),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: _isEmail
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          child: const Text('Email'),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isEmail = false),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: !_isEmail
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          child: const Text('Phone'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// Magic link sent confirmation screen
  Widget _buildMagicLinkSentContent() {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),

          // Success icon with gradient background
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            'Check your email!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Subtitle with email
          Text(
            'We sent a magic link to',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Email address highlighted
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primaryOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryOrange.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              _contactInfo,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.primaryOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Instruction text
          Text(
            'Click the link in the email to sign in.\nThe link will expire in 1 hour.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Back to login button - full width
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _magicLinkSent = false;
                  _contactInfo = '';
                });
              },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back to login'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: AppTheme.textSecondary,
                side: BorderSide(color: AppTheme.surfaceBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Resend link
          TextButton(
            onPressed: () {
              if (_contactInfo.isNotEmpty) {
                context.read<AuthBloc>().add(
                  SignInWithEmailRequested(_contactInfo),
                );
              }
            },
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: "Didn't receive email? ",
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                  TextSpan(
                    text: 'Resend',
                    style: TextStyle(
                      color: AppTheme.accentCyan,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
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
          child: GradientButton(text: 'Verify', onPressed: _verifyOTP),
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
