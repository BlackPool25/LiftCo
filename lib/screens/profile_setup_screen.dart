// lib/screens/profile_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth_bloc.dart';
import '../config/theme.dart';
import '../models/user.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _bioController = TextEditingController();
  final _monthsController = TextEditingController();

  String? _selectedGender;
  String? _selectedExperience;
  String? _selectedPreferredTime;
  String? _selectedWorkoutSplit;

  int _currentStep = 0;
  final int _totalSteps = 4;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    _monthsController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep < _totalSteps - 1) {
        setState(() => _currentStep++);
      } else {
        _completeProfile();
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_nameController.text.trim().isEmpty) {
          _showError('Please enter your name');
          return false;
        }
        if (_ageController.text.isEmpty || int.parse(_ageController.text) < 13) {
          _showError('Please enter a valid age (13+)');
          return false;
        }
        if (_selectedGender == null) {
          _showError('Please select your gender');
          return false;
        }
        return true;
      case 1:
        if (_selectedExperience == null) {
          _showError('Please select your experience level');
          return false;
        }
        return true;
      case 2:
        if (_selectedPreferredTime == null) {
          _showError('Please select your preferred workout time');
          return false;
        }
        return true;
      case 3:
        return true;
      default:
        return true;
    }
  }

  void _completeProfile() {
    context.read<AuthBloc>().add(CompleteProfileRequested(
          name: _nameController.text.trim(),
          age: int.parse(_ageController.text),
          gender: _selectedGender!,
          experienceLevel: _selectedExperience!,
          preferredTime: _selectedPreferredTime!,
          currentWorkoutSplit: _selectedWorkoutSplit,
          timeWorkingOutMonths: _monthsController.text.isNotEmpty
              ? int.parse(_monthsController.text)
              : null,
          bio: _bioController.text.trim().isNotEmpty
              ? _bioController.text.trim()
              : null,
        ));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            _showError(state.message);
          }
        },
        builder: (context, state) {
          if (state is AuthLoading) {
            return Container(
              decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryPurple),
              ),
            );
          }

          return Container(
            decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
            child: Stack(
              children: [
                // Background orbs
                _buildBackgroundOrbs(),
                
                // Main content
                SafeArea(
                  child: Column(
                    children: [
                      // Progress Bar
                      _buildProgressBar(),

                      // Content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _buildStepContent(),
                          ),
                        ),
                      ),

                      // Navigation Buttons
                      _buildNavigationButtons(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackgroundOrbs() {
    return Stack(
      children: [
        Positioned(
          top: 150,
          right: -80,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primaryPurple.withValues(alpha: 0.2),
                  AppTheme.primaryPurple.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 150,
          left: -60,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.accentCyan.withValues(alpha: 0.15),
                  AppTheme.accentCyan.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (index) {
              final isActive = index <= _currentStep;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
                  decoration: BoxDecoration(
                    gradient: isActive ? AppTheme.primaryGradient : null,
                    color: isActive ? null : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getStepTitle(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_currentStep + 1}/$_totalSteps',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Basic Info';
      case 1:
        return 'Experience';
      case 2:
        return 'Schedule';
      case 3:
        return 'Final Details';
      default:
        return '';
    }
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildExperienceStep();
      case 2:
        return _buildPreferredTimeStep();
      case 3:
        return _buildAdditionalInfoStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBasicInfoStep() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Let\'s get to know you',
          style: Theme.of(context).textTheme.headlineMedium,
        ).animate().fadeIn().slideX(),
        const SizedBox(height: 8),
        Text(
          'We\'ll use this to find your perfect gym buddy',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 32),

        // Name field
        GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: 16,
          child: TextField(
            controller: _nameController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Full Name',
              hintText: 'Enter your name',
              prefixIcon: const Icon(Icons.person_outline, color: AppTheme.textMuted),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              fillColor: Colors.transparent,
              filled: true,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Age field
        GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: 16,
          child: TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppTheme.textPrimary),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(
              labelText: 'Age',
              hintText: 'Your age',
              prefixIcon: const Icon(Icons.cake_outlined, color: AppTheme.textMuted),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              fillColor: Colors.transparent,
              filled: true,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Gender Selection
        Text(
          'Gender',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: Gender.values.map((gender) {
            final isSelected = _selectedGender == gender['value'];
            return _buildSelectionChip(
              label: gender['label'] as String,
              icon: gender['icon'] as IconData,
              isSelected: isSelected,
              onTap: () => setState(() => _selectedGender = gender['value'] as String),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildExperienceStep() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your fitness level',
          style: Theme.of(context).textTheme.headlineMedium,
        ).animate().fadeIn().slideX(),
        const SizedBox(height: 8),
        Text(
          'We\'ll match you with buddies at a similar level',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 32),

        ...ExperienceLevel.values.map((exp) {
          final isSelected = _selectedExperience == exp['value'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildExperienceCard(
              label: exp['label'] as String,
              description: exp['description'] as String,
              icon: exp['icon'] as IconData,
              color: Color(exp['color'] as int),
              isSelected: isSelected,
              onTap: () =>
                  setState(() => _selectedExperience = exp['value'] as String),
            ),
          );
        }),

        const SizedBox(height: 20),

        // Months working out
        Text(
          'Time training (optional)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: 16,
          child: TextField(
            controller: _monthsController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppTheme.textPrimary),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(
              hintText: 'Number of months',
              prefixIcon: const Icon(Icons.timer_outlined, color: AppTheme.textMuted),
              suffixText: 'months',
              suffixStyle: const TextStyle(color: AppTheme.textMuted),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              fillColor: Colors.transparent,
              filled: true,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildPreferredTimeStep() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When do you train?',
          style: Theme.of(context).textTheme.headlineMedium,
        ).animate().fadeIn().slideX(),
        const SizedBox(height: 8),
        Text(
          'Find buddies who train at the same time',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 32),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.15,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: PreferredTime.values.length,
          itemBuilder: (context, index) {
            final time = PreferredTime.values[index];
            final isSelected = _selectedPreferredTime == time['value'];
            return _buildTimeCard(
              label: time['label'] as String,
              time: time['time'] as String,
              icon: time['icon'] as IconData,
              gradientColors: (time['gradient'] as List<dynamic>).cast<int>(),
              isSelected: isSelected,
              onTap: () =>
                  setState(() => _selectedPreferredTime = time['value'] as String),
            );
          },
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildAdditionalInfoStep() {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Almost done!',
          style: Theme.of(context).textTheme.headlineMedium,
        ).animate().fadeIn().slideX(),
        const SizedBox(height: 8),
        Text(
          'Just a few optional details',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 32),

        // Workout Split
        Text(
          'Current workout split',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: WorkoutSplit.values.map((split) {
            final isSelected = _selectedWorkoutSplit == split['value'];
            return FilterChip(
              label: Text(split['label'] as String),
              selected: isSelected,
              onSelected: (_) =>
                  setState(() => _selectedWorkoutSplit = split['value'] as String),
              selectedColor: AppTheme.primaryPurple,
              backgroundColor: AppTheme.surface,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryPurple : AppTheme.surfaceBorder,
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 28),

        // Bio
        Text(
          'Bio',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: 16,
          child: TextField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 200,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Tell others about yourself...',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              fillColor: Colors.transparent,
              filled: true,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              flex: 1,
              child: GlassButton(
                text: 'Back',
                onPressed: _previousStep,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: _currentStep > 0 ? 2 : 1,
            child: GradientButton(
              text: _currentStep == _totalSteps - 1 ? 'Complete' : 'Continue',
              onPressed: _nextStep,
              icon: _currentStep == _totalSteps - 1 ? Icons.check : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.primaryGradient : null,
          color: isSelected ? null : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppTheme.surfaceBorder,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceCard({
    required String label,
    required String description,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        borderRadius: 20,
        backgroundColor: isSelected
            ? color.withValues(alpha: 0.15)
            : AppTheme.glassBackground,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? color : AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCard({
    required String label,
    required String time,
    required IconData icon,
    required List<int> gradientColors,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(gradientColors[0]), Color(gradientColors[1])],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Color(gradientColors[0]).withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: Colors.white, size: 28),
                  const Spacer(),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: AppTheme.success,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
