// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../blocs/auth_bloc.dart';
import '../config/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isEmail = true;
  String _contactInfo = '';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
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
      setState(() {
        _contactInfo = email;
      });
    } else {
      String phone = _phoneController.text.trim();
      if (phone.isEmpty || phone.length < 10) {
        _showError('Please enter a valid phone number');
        return;
      }
      // Add + if not present
      if (!phone.startsWith('+')) {
        phone = '+1$phone'; // Default to US
      }
      context.read<AuthBloc>().add(SignInWithPhoneRequested(phone));
      setState(() {
        _contactInfo = phone;
      });
    }
  }
  
  void _verifyOTP() {
    final otp = _otpController.text.trim();
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
          if (state is AuthLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }
          
          return Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.surfaceGradient,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    // Logo & Title
                    _buildHeader()
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .slideY(begin: -0.2, end: 0),
                    
                    const SizedBox(height: 48),
                    
                    // OAuth Buttons
                    if (!_otpSent) ...[
                      _buildOAuthButtons()
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 600.ms),
                      
                      const SizedBox(height: 32),
                      
                      // Divider
                      _buildDivider()
                          .animate()
                          .fadeIn(delay: 300.ms, duration: 600.ms),
                      
                      const SizedBox(height: 32),
                      
                      // Tab Bar for Email/Phone
                      _buildTabBar()
                          .animate()
                          .fadeIn(delay: 400.ms, duration: 600.ms),
                      
                      const SizedBox(height: 24),
                      
                      // Tab Content
                      _buildTabContent()
                          .animate()
                          .fadeIn(delay: 500.ms, duration: 600.ms),
                    ] else ...[
                      // OTP Verification
                      _buildOTPVerification()
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideX(begin: 0.2, end: 0),
                    ],
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.fitness_center,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _otpSent ? 'Verify OTP' : 'Welcome to\nLiftCo',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _otpSent
            ? 'Enter the 6-digit code sent to ${_isEmail ? 'email' : 'phone'}'
            : 'Find workout partners at your gym',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
  
  Widget _buildOAuthButtons() {
    return Column(
      children: [
        _buildOAuthButton(
          icon: FontAwesomeIcons.google,
          label: 'Continue with Google',
          color: Colors.white,
          textColor: Colors.black87,
          onTap: _signInWithGoogle,
        ),
        const SizedBox(height: 12),
        _buildOAuthButton(
          icon: FontAwesomeIcons.apple,
          label: 'Continue with Apple',
          color: Colors.white,
          textColor: Colors.black87,
          onTap: _signInWithApple,
        ),
      ],
    );
  }
  
  Widget _buildOAuthButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, size: 20, color: textColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppTheme.textMuted.withOpacity(0.3))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppTheme.textMuted.withOpacity(0.3))),
      ],
    );
  }
  
  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Email'),
          Tab(text: 'Phone'),
        ],
      ),
    );
  }
  
  Widget _buildTabContent() {
    return SizedBox(
      height: 200,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildEmailForm(),
          _buildPhoneForm(),
        ],
      ),
    );
  }
  
  Widget _buildEmailForm() {
    return Column(
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Enter your email',
            prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _sendOTP,
            child: const Text('Send OTP'),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPhoneForm() {
    return Column(
      children: [
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: AppTheme.textPrimary),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(15),
          ],
          decoration: const InputDecoration(
            hintText: 'Enter your phone number',
            prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.textMuted),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _sendOTP,
            child: const Text('Send OTP'),
          ),
        ),
      ],
    );
  }
  
  Widget _buildOTPVerification() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                maxLength: 6,
                decoration: const InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(vertical: 20),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _verifyOTP,
                  child: const Text('Verify'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () {
            setState(() {
              _otpSent = false;
              _otpController.clear();
            });
          },
          child: Text('Change ${_isEmail ? 'Email' : 'Phone'}'),
        ),
      ],
    );
  }
}
