// lib/screens/create_session_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../models/gym.dart';
import '../services/gym_service.dart';
import '../services/current_user_resolver.dart';
import '../services/session_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

class CreateSessionScreen extends StatefulWidget {
  final Gym? gym;

  const CreateSessionScreen({super.key, this.gym});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  late SessionService _sessionService;
  late GymService _gymService;
  final _formKey = GlobalKey<FormState>();

  // Form fields
  final _titleController = TextEditingController();
  final _sessionTypeController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 18, minute: 0);
  int _durationMinutes = 60;
  int _maxCapacity = 4;
  String? _intensityLevel;
  Gym? _selectedGym;
  List<Gym> _availableGyms = [];
  bool _isLoadingGyms = false;

  bool _isLoading = false;

  final List<int> _durationOptions = [30, 45, 60, 90, 120];
  final List<int> _capacityOptions = [2, 3, 4, 5, 6, 8, 10];
  final List<String> _intensityOptions = [
    'Light',
    'Moderate',
    'Intense',
    'Extreme',
  ];

  // Women safety feature
  bool _womenOnly = false;
  String? _currentUserGender;

  @override
  void initState() {
    super.initState();
    _sessionService = SessionService(Supabase.instance.client);
    _gymService = GymService(Supabase.instance.client);
    _selectedGym = widget.gym;

    // Load current user gender for women-only feature
    _loadCurrentUserGender();

    // If no gym is pre-selected, load the list of gyms
    if (widget.gym == null) {
      _loadGyms();
    }
  }

  Future<void> _loadCurrentUserGender() async {
    try {
      final profile = await CurrentUserResolver.resolveCurrentUserProfile(
        Supabase.instance.client,
      );
      if (profile != null) {
        setState(() {
          _currentUserGender = profile['gender'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading user gender: $e');
    }
  }

  Future<void> _loadGyms() async {
    setState(() {
      _isLoadingGyms = true;
    });

    try {
      final gyms = await _gymService.getGyms();
      setState(() {
        _availableGyms = gyms;
        _isLoadingGyms = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingGyms = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load gyms: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sessionTypeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryPurple,
              surface: AppTheme.surface,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showGymSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select Gym',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a gym for your workout session',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _availableGyms.length,
                itemBuilder: (context, index) {
                  final gym = _availableGyms[index];
                  final isSelected = _selectedGym?.id == gym.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedGym = gym;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryPurple.withValues(alpha: 0.2)
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryPurple
                              : AppTheme.surfaceBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? AppTheme.primaryGradient
                                  : null,
                              color: isSelected ? null : AppTheme.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.fitness_center,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  gym.name,
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  gym.formattedAddress,
                                  style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: AppTheme.primaryPurple,
                              size: 24,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryPurple,
              surface: AppTheme.surface,
              onSurface: AppTheme.textPrimary,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppTheme.surface,
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _createSession() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate gym is selected
    if (_selectedGym == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a gym'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Combine date and time
      final startTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Validate start time is in the future
      if (startTime.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session time must be in the future'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }

      await _sessionService.createSession(
        gymId: _selectedGym!.id,
        title: _titleController.text.trim(),
        sessionType: _sessionTypeController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        startTime: startTime,
        durationMinutes: _durationMinutes,
        maxCapacity: _maxCapacity,
        intensityLevel: _intensityLevel,
        womenOnly: _womenOnly,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session created successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create session: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              _buildAppBar(),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Gym selection
                        if (widget.gym != null)
                          // Pre-selected gym - show info card
                          GlassCard(
                            padding: const EdgeInsets.all(16),
                            borderRadius: 16,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.fitness_center,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Creating session at',
                                        style: TextStyle(
                                          color: AppTheme.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.gym!.name,
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn().slideY(begin: -0.1)
                        else
                          // No gym pre-selected - show dropdown
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('Select Gym *'),
                              const SizedBox(height: 8),
                              if (_isLoadingGyms)
                                GlassCard(
                                  padding: const EdgeInsets.all(16),
                                  borderRadius: 16,
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.primaryPurple,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Loading gyms...',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (_availableGyms.isEmpty)
                                GlassCard(
                                  padding: const EdgeInsets.all(16),
                                  borderRadius: 16,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: AppTheme.warning,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'No gyms available',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _loadGyms,
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                GestureDetector(
                                  onTap: _showGymSelector,
                                  child: GlassCard(
                                    padding: const EdgeInsets.all(16),
                                    borderRadius: 16,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            gradient: AppTheme.primaryGradient,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.fitness_center,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Selected Gym',
                                                style: TextStyle(
                                                  color: AppTheme.textMuted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _selectedGym?.name ??
                                                    'Tap to select a gym',
                                                style: TextStyle(
                                                  color: _selectedGym != null
                                                      ? AppTheme.textPrimary
                                                      : AppTheme.textMuted,
                                                  fontSize: 15,
                                                  fontWeight:
                                                      _selectedGym != null
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_drop_down,
                                          color: AppTheme.textMuted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ).animate().fadeIn().slideY(begin: -0.1),

                        const SizedBox(height: 24),

                        // Title field
                        _buildSectionTitle('Session Title *'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _titleController,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: _inputDecoration(
                            'e.g., Morning Push Day',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a session title';
                            }
                            return null;
                          },
                        ).animate().fadeIn(delay: 50.ms),

                        const SizedBox(height: 20),

                        // Session type field
                        _buildSectionTitle('Workout Type *'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _sessionTypeController,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: _inputDecoration(
                            'e.g., Push Pull Legs, Upper/Lower, etc.',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a workout type';
                            }
                            return null;
                          },
                        ).animate().fadeIn(delay: 100.ms),

                        const SizedBox(height: 20),

                        // Date and Time
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle('Date *'),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: _selectDate,
                                    child: GlassCard(
                                      padding: const EdgeInsets.all(16),
                                      borderRadius: 12,
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today,
                                            color: AppTheme.accentCyan,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                            style: const TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle('Time *'),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: _selectTime,
                                    child: GlassCard(
                                      padding: const EdgeInsets.all(16),
                                      borderRadius: 12,
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time,
                                            color: AppTheme.accentCyan,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                                            style: const TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 150.ms),

                        const SizedBox(height: 20),

                        // Duration
                        _buildSectionTitle('Duration'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _durationOptions.map((minutes) {
                            final isSelected = _durationMinutes == minutes;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _durationMinutes = minutes;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? AppTheme.primaryGradient
                                      : null,
                                  color: isSelected ? null : AppTheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.transparent
                                        : AppTheme.surfaceBorder,
                                  ),
                                ),
                                child: Text(
                                  minutes < 60
                                      ? '$minutes min'
                                      : '${minutes ~/ 60}h ${minutes % 60 > 0 ? '${minutes % 60}m' : ''}',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 20),

                        // Max capacity
                        _buildSectionTitle('Max Participants'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _capacityOptions.map((capacity) {
                            final isSelected = _maxCapacity == capacity;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _maxCapacity = capacity;
                                });
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? AppTheme.primaryGradient
                                      : null,
                                  color: isSelected ? null : AppTheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.transparent
                                        : AppTheme.surfaceBorder,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '$capacity',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.textSecondary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ).animate().fadeIn(delay: 250.ms),

                        const SizedBox(height: 20),

                        // Intensity level
                        _buildSectionTitle('Intensity Level'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _intensityOptions.map((level) {
                            final isSelected = _intensityLevel == level;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _intensityLevel = level;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? AppTheme.accentGradient
                                      : null,
                                  color: isSelected ? null : AppTheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.transparent
                                        : AppTheme.surfaceBorder,
                                  ),
                                ),
                                child: Text(
                                  level,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ).animate().fadeIn(delay: 300.ms),

                        const SizedBox(height: 20),

                        // Women-Only Toggle (Female users only)
                        if (_currentUserGender == 'female')
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('Session Type'),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _womenOnly = !_womenOnly;
                                  });
                                },
                                child: GlassCard(
                                  padding: const EdgeInsets.all(16),
                                  borderRadius: 16,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          gradient: _womenOnly
                                              ? LinearGradient(
                                                  colors: [
                                                    Colors.pink[300]!,
                                                    Colors.purple[400]!,
                                                  ],
                                                )
                                              : null,
                                          color: _womenOnly
                                              ? null
                                              : AppTheme.surfaceLight,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          _womenOnly
                                              ? Icons.female
                                              : Icons.groups,
                                          color: _womenOnly
                                              ? Colors.white
                                              : AppTheme.textSecondary,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _womenOnly
                                                  ? 'Women Only'
                                                  : 'General Session',
                                              style: const TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _womenOnly
                                                  ? 'Only women can see and join this session'
                                                  : 'Open to everyone',
                                              style: TextStyle(
                                                color: AppTheme.textMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch.adaptive(
                                        value: _womenOnly,
                                        onChanged: (value) {
                                          setState(() {
                                            _womenOnly = value;
                                          });
                                        },
                                        activeThumbColor: Colors.pink[400],
                                        activeTrackColor: Colors.pink[200]!
                                            .withValues(alpha: 0.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),

                        // Description
                        _buildSectionTitle('Description (Optional)'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionController,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          maxLines: 3,
                          decoration: _inputDecoration(
                            'Add any details about the session...',
                          ),
                        ).animate().fadeIn(delay: 350.ms),

                        const SizedBox(height: 32),

                        // Create button
                        GradientButton(
                          text: 'Create Session',
                          icon: Icons.add,
                          isLoading: _isLoading,
                          onPressed: _createSession,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ).animate().fadeIn(delay: 400.ms),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GlassCard(
            onTap: () => Navigator.pop(context),
            padding: const EdgeInsets.all(12),
            borderRadius: 14,
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Create Session',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textMuted),
      filled: true,
      fillColor: AppTheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.error, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
