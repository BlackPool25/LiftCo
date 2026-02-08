// lib/screens/profile_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth_bloc.dart';
import '../config/theme.dart';
import '../models/user.dart';

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
      bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
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
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }
          
          return Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.surfaceGradient,
            ),
            child: SafeArea(
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
          );
        },
      ),
    );
  }
  
  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (index) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
                  decoration: BoxDecoration(
                    gradient: index <= _currentStep 
                      ? AppTheme.primaryGradient
                      : null,
                    color: index <= _currentStep ? null : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${_currentStep + 1} of $_totalSteps',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
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
          'Basic information to create your profile',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 32),
        
        // Name
        TextField(
          controller: _nameController,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Full Name',
            hintText: 'Enter your name',
            prefixIcon: Icon(Icons.person_outline, color: AppTheme.textMuted),
          ),
        ),
        const SizedBox(height: 20),
        
        // Age
        TextField(
          controller: _ageController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppTheme.textPrimary),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: const InputDecoration(
            labelText: 'Age',
            hintText: 'Your age',
            prefixIcon: Icon(Icons.calendar_today, color: AppTheme.textMuted),
          ),
        ),
        const SizedBox(height: 24),
        
        // Gender Selection Cards
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
            return _buildSelectionCard(
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
          'Experience Level',
          style: Theme.of(context).textTheme.headlineMedium,
        ).animate().fadeIn().slideX(),
        const SizedBox(height: 8),
        Text(
          'How would you describe your fitness journey?',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 32),
        
        ...ExperienceLevel.values.map((exp) {
          final isSelected = _selectedExperience == exp['value'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildExperienceCard(
              label: exp['label'] as String,
              description: exp['description'] as String,
              icon: exp['icon'] as IconData,
              color: Color(exp['color'] as int),
              isSelected: isSelected,
              onTap: () => setState(() => _selectedExperience = exp['value'] as String),
            ),
          );
        }).toList(),
        
        const SizedBox(height: 24),
        
        // Months working out
        Text(
          'How long have you been working out? (optional)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _monthsController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppTheme.textPrimary),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: const InputDecoration(
            hintText: 'Number of months',
            prefixIcon: Icon(Icons.timer, color: AppTheme.textMuted),
            suffixText: 'months',
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
          'When do you usually work out?',
          style: Theme.of(context).textTheme.headlineMedium,
        ).animate().fadeIn().slideX(),
        const SizedBox(height: 8),
        Text(
          'Select your preferred time period',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 32),
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
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
              onTap: () => setState(() => _selectedPreferredTime = time['value'] as String),
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
          'A few more details to complete your profile',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 32),
        
        // Workout Split
        Text(
          'Current Workout Split (optional)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: WorkoutSplit.values.map((split) {
            final isSelected = _selectedWorkoutSplit == split['value'];
            return ChoiceChip(
              label: Text(split['label'] as String),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedWorkoutSplit = split['value'] as String),
              selectedColor: AppTheme.primaryColor,
              backgroundColor: AppTheme.surface,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceLight,
                ),
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 32),
        
        // Bio
        TextField(
          controller: _bioController,
          maxLines: 4,
          maxLength: 200,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Bio (optional)',
            hintText: 'Tell others about yourself...',
            alignLabelWithHint: true,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
  
  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.background.withOpacity(0),
            AppTheme.background,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: _currentStep > 0 ? 2 : 1,
            child: ElevatedButton(
              onPressed: _nextStep,
              child: Text(_currentStep == _totalSteps - 1 ? 'Complete' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }
  
  // Reusable Widgets
  
  Widget _buildSelectionCard({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceLight,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppTheme.surfaceLight,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 28),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(gradientColors[0]),
              Color(gradientColors[1]),
            ],
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
                  color: Color(gradientColors[0]).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: Colors.white, size: 28),
                  const Spacer(),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
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
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: AppTheme.success,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
