// lib/screens/home_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../models/user.dart' as app_user;
import '../models/workout_session.dart';
import '../services/gym_service.dart';
import '../services/session_service.dart';
import '../services/user_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import 'gym_details_screen.dart';
import 'session_details_screen.dart';

/// Home tab - main dashboard with stats and sessions
class HomeTab extends StatefulWidget {
  final app_user.User user;
  final VoidCallback onNavigateToGyms;

  const HomeTab({
    super.key,
    required this.user,
    required this.onNavigateToGyms,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late SessionService _sessionService;
  late GymService _gymService;
  late UserService _userService;

  List<WorkoutSession> _allSessions = [];
  List<WorkoutSession> _filteredSessions = [];
  bool _isLoadingSessions = true;
  String? _sessionsError;

  // Filter state
  String? _filterIntensity;
  String? _filterTimeRange;
  int? _filterDuration;

  // Women safety feature
  bool _femaleOnlyMode = false;

  @override
  void initState() {
    super.initState();
    _sessionService = SessionService(Supabase.instance.client);
    _gymService = GymService(Supabase.instance.client);
    _userService = UserService(Supabase.instance.client);
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoadingSessions = true;
      _sessionsError = null;
    });

    try {
      // Fetch upcoming sessions from all gyms
      final response = await Supabase.instance.client
          .from('workout_sessions')
          .select('''
            *,
            host:host_user_id(id, name),
            gym:gym_id(name)
          ''')
          .eq('status', 'upcoming')
          .gte('start_time', DateTime.now().toIso8601String())
          .order('start_time', ascending: true);

      final sessions = (response as List)
          .map((json) => WorkoutSession.fromJson(json))
          .where((s) => !s.isFull)
          .toList();

      setState(() {
        _allSessions = sessions;
        _filteredSessions = sessions;
        _isLoadingSessions = false;
      });
    } catch (e) {
      setState(() {
        _sessionsError = e.toString();
        _isLoadingSessions = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredSessions = _allSessions.where((session) {
        // Filter by female-only mode
        if (_femaleOnlyMode && !session.isWomenOnly) {
          return false;
        }

        // Filter by intensity
        if (_filterIntensity != null &&
            session.intensityLevel?.toLowerCase() !=
                _filterIntensity!.toLowerCase()) {
          return false;
        }

        // Filter by time range
        if (_filterTimeRange != null) {
          final hour = session.startTime.hour;
          switch (_filterTimeRange) {
            case 'morning':
              if (hour < 5 || hour >= 12) return false;
              break;
            case 'afternoon':
              if (hour < 12 || hour >= 17) return false;
              break;
            case 'evening':
              if (hour < 17 || hour >= 22) return false;
              break;
          }
        }

        // Filter by duration
        if (_filterDuration != null &&
            session.durationMinutes != _filterDuration) {
          return false;
        }

        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _filterIntensity = null;
      _filterTimeRange = null;
      _filterDuration = null;
      _filteredSessions = _allSessions;
    });
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Text(
                      'Filter Sessions',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    if (_filterIntensity != null ||
                        _filterTimeRange != null ||
                        _filterDuration != null)
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _clearFilters();
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Clear All'),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Intensity filter
                Text(
                  'Intensity Level',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['Light', 'Moderate', 'Intense', 'Extreme'].map((
                    intensity,
                  ) {
                    final isSelected = _filterIntensity == intensity;
                    return ChoiceChip(
                      label: Text(intensity),
                      selected: isSelected,
                      onSelected: (selected) {
                        setModalState(() {
                          _filterIntensity = selected ? intensity : null;
                        });
                      },
                      backgroundColor: AppTheme.surfaceLight,
                      selectedColor: AppTheme.primaryPurple.withValues(
                        alpha: 0.3,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppTheme.primaryPurple
                            : AppTheme.textSecondary,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Time range filter
                Text(
                  'Time of Day',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children:
                      [
                        {'label': 'Morning (5AM-12PM)', 'value': 'morning'},
                        {'label': 'Afternoon (12PM-5PM)', 'value': 'afternoon'},
                        {'label': 'Evening (5PM-10PM)', 'value': 'evening'},
                      ].map((time) {
                        final isSelected = _filterTimeRange == time['value'];
                        return ChoiceChip(
                          label: Text(time['label']!),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              _filterTimeRange = selected
                                  ? time['value']
                                  : null;
                            });
                          },
                          backgroundColor: AppTheme.surfaceLight,
                          selectedColor: AppTheme.primaryPurple.withValues(
                            alpha: 0.3,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppTheme.primaryPurple
                                : AppTheme.textSecondary,
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 24),

                // Duration filter
                Text(
                  'Duration',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [30, 45, 60, 90, 120].map((duration) {
                    final isSelected = _filterDuration == duration;
                    return ChoiceChip(
                      label: Text(
                        duration < 60 ? '$duration min' : '${duration ~/ 60}h',
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setModalState(() {
                          _filterDuration = selected ? duration : null;
                        });
                      },
                      backgroundColor: AppTheme.surfaceLight,
                      selectedColor: AppTheme.primaryPurple.withValues(
                        alpha: 0.3,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppTheme.primaryPurple
                            : AppTheme.textSecondary,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                // Apply button
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    text: 'Apply Filters',
                    onPressed: () {
                      _applyFilters();
                      Navigator.pop(context);
                    },
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showPreferredTimePicker() async {
    await showModalBottomSheet(
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
              'Select Preferred Time',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'When do you prefer to work out?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ...app_user.PreferredTime.values.map((time) {
              final isSelected = widget.user.preferredTime == time['value'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () async {
                    try {
                      await _userService.updatePreferredTime(
                        time['value'] as String,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        // Refresh the page
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Preferred time updated!'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to update: $e'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppTheme.primaryGradient : null,
                      color: isSelected ? null : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : AppTheme.surfaceBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.2)
                                : AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            time['icon'] as IconData,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textSecondary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                time['label'] as String,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                time['time'] as String,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : AppTheme.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background gradient orbs
        _buildBackgroundOrbs(),

        // Main content
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Bar
                _buildAppBar(context)
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: -0.2, end: 0),

                const SizedBox(height: 24),

                // Greeting
                Text(
                  'Hey, ${widget.user.name.split(' ').first}! 👋',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 8),

                Text(
                  'Ready to crush\nyour workout?',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    height: 1.2,
                  ),
                ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),

                const SizedBox(height: 24),

                // Compact Stats Section
                _buildCompactStatsSection(
                  context,
                ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

                const SizedBox(height: 24),

                // Single line Explore Sessions CTA
                _buildCompactExploreCTA(
                  context,
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),

                const SizedBox(height: 32),

                // Available Sessions Section
                _buildSessionsSection(
                  context,
                ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundOrbs() {
    return Stack(
      children: [
        Positioned(
          top: 100,
          right: -50,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primaryOrange.withValues(alpha: 0.15),
                  AppTheme.primaryOrange.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 200,
          left: -30,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primaryBlue.withValues(alpha: 0.12),
                  AppTheme.primaryBlue.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Row(
      children: [
        // Menu icon
        GlassCard(
          padding: const EdgeInsets.all(12),
          borderRadius: 14,
          child: const Icon(
            Icons.menu_rounded,
            color: AppTheme.textPrimary,
            size: 22,
          ),
        ),
        const Spacer(),
        // Compact Reputation badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryOrange.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.star, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(
                '${widget.user.reputationScore}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Notification bell
        GlassCard(
          padding: const EdgeInsets.all(12),
          borderRadius: 14,
          onTap: () {},
          child: Stack(
            children: [
              const Icon(
                Icons.notifications_outlined,
                color: AppTheme.textPrimary,
                size: 22,
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Female-only mode toggle (for female users only)
        if (widget.user.gender == 'female') ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _femaleOnlyMode = !_femaleOnlyMode;
              });
              _applyFilters();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                gradient: _femaleOnlyMode
                    ? LinearGradient(
                        colors: [Colors.pink[400]!, Colors.purple[500]!],
                      )
                    : null,
                color: _femaleOnlyMode ? null : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _femaleOnlyMode
                      ? Colors.transparent
                      : AppTheme.surfaceBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _femaleOnlyMode ? Icons.female : Icons.groups,
                    color: _femaleOnlyMode
                        ? Colors.white
                        : AppTheme.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _femaleOnlyMode ? 'Women' : 'All',
                    style: TextStyle(
                      color: _femaleOnlyMode
                          ? Colors.white
                          : AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactStatsSection(BuildContext context) {
    final timeData = app_user.PreferredTime.values.firstWhere(
      (t) => t['value'] == widget.user.preferredTime,
      orElse: () => app_user.PreferredTime.values[1],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact Reputation and Level row
        Row(
          children: [
            Expanded(
              child: _buildCompactStatItem(
                icon: Icons.emoji_events_outlined,
                label: 'Rep',
                value: '${widget.user.reputationScore}',
                iconColor: AppTheme.warning,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCompactStatItem(
                icon: Icons.fitness_center,
                label: 'Lvl',
                value: widget.user.experienceLevel != null
                    ? widget.user.experienceLevel!.substring(0, 1).toUpperCase()
                    : 'B',
                iconColor: AppTheme.success,
              ),
            ),
            const SizedBox(width: 8),
            // Preferred Time with edit button
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _showPreferredTimePicker,
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  borderRadius: 16,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color((timeData['gradient'] as List)[0]),
                              Color((timeData['gradient'] as List)[1]),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          timeData['icon'] as IconData,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${timeData['label']}',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${timeData['time']}',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.edit, color: AppTheme.textMuted, size: 14),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: 16,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactExploreCTA(BuildContext context) {
    return GestureDetector(
      onTap: widget.onNavigateToGyms,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: 16,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.explore_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Explore Sessions',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Find workout partners near you',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with filter button
        Row(
          children: [
            Text(
              'Available Sessions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            if (_filteredSessions.isNotEmpty)
              Text(
                '${_filteredSessions.length} found',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showFilterDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      (_filterIntensity != null ||
                          _filterTimeRange != null ||
                          _filterDuration != null)
                      ? AppTheme.primaryPurple.withValues(alpha: 0.2)
                      : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        (_filterIntensity != null ||
                            _filterTimeRange != null ||
                            _filterDuration != null)
                        ? AppTheme.primaryPurple
                        : AppTheme.surfaceBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.filter_list,
                      color:
                          (_filterIntensity != null ||
                              _filterTimeRange != null ||
                              _filterDuration != null)
                          ? AppTheme.primaryPurple
                          : AppTheme.textSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Filter',
                      style: TextStyle(
                        color:
                            (_filterIntensity != null ||
                                _filterTimeRange != null ||
                                _filterDuration != null)
                            ? AppTheme.primaryPurple
                            : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Sessions list
        if (_isLoadingSessions)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppTheme.primaryPurple),
            ),
          )
        else if (_sessionsError != null)
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppTheme.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load sessions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loadSessions,
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (_filteredSessions.isEmpty)
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    color: AppTheme.textMuted,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _allSessions.isEmpty
                      ? 'No sessions available'
                      : 'No sessions match filters',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_allSessions.isNotEmpty &&
                    (_filterIntensity != null ||
                        _filterTimeRange != null ||
                        _filterDuration != null))
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear Filters'),
                  ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredSessions.length > 5
                ? 5
                : _filteredSessions.length,
            itemBuilder: (context, index) {
              return _buildSessionCard(_filteredSessions[index], index);
            },
          ),

        // View all button
        if (_filteredSessions.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: TextButton(
                onPressed: widget.onNavigateToGyms,
                child: const Text('View All Sessions'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSessionCard(WorkoutSession session, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SessionDetailsScreen(session: session),
          ),
        );
      },
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderRadius: 14,
        margin: const EdgeInsets.only(bottom: 12),
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
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        session.sessionType,
                        style: const TextStyle(
                          color: AppTheme.accentCyan,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• ${session.formattedDate}',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      if (session.isWomenOnly) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.pink[400]!, Colors.purple[500]!],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.female, color: Colors.white, size: 10),
                              SizedBox(width: 2),
                              Text(
                                'Women',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: session.availableSpots > 2
                    ? AppTheme.success.withValues(alpha: 0.2)
                    : AppTheme.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${session.availableSpots} left',
                style: TextStyle(
                  color: session.availableSpots > 2
                      ? AppTheme.success
                      : AppTheme.warning,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (300 + index * 50).ms);
  }
}
