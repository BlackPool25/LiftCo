// lib/screens/home_tab.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../models/user.dart' as app_user;
import '../models/gym.dart';
import '../models/workout_session.dart';
import '../services/gym_service.dart';
import '../services/user_service.dart';
import '../services/session_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
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
  late UserService _userService;
  late SessionService _sessionService;
  late GymService _gymService;

  List<WorkoutSession> _allSessions = [];
  List<WorkoutSession> _filteredSessions = [];
  bool _isLoadingSessions = true;
  String? _sessionsError;

  // Filter state
  String? _filterIntensity;
  String? _filterTimeRange;
  int? _filterDuration;
  int? _filterGymId;

  // Gyms list for filters
  List<Gym> _gyms = [];
  bool _isLoadingGyms = false;

  // Women safety feature
  bool _femaleOnlyMode = false;

  // User state - to allow updates
  late app_user.User _currentUser;

  // Pagination
  static const int _sessionsPerPage = 10;
  int _currentPage = 0;
  bool _hasMoreSessions = true;
  bool _isLoadingMore = false;
  final Set<String> _userJoinedSessionIds = {};

  // Realtime subscriptions
  final Map<String, StreamSubscription<WorkoutSession?>> _sessionSubscriptions =
      {};
  StreamSubscription<List<WorkoutSession>>? _newSessionsSubscription;
  // NOTE: We no longer poll memberships separately; sessions-list already
  // returns `is_user_joined`, and visible session subscriptions keep it fresh.

  // Flag to prevent subscription from adding duplicates during initial load
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _userService = UserService(Supabase.instance.client);
    _sessionService = SessionService(Supabase.instance.client);
    _gymService = GymService(Supabase.instance.client);
    _currentUser = widget.user;
    _loadSessions();
    _loadGyms();
    _subscribeToRecentSessions();
  }

  @override
  void dispose() {
    // Cancel all individual session subscriptions
    for (final subscription in _sessionSubscriptions.values) {
      subscription.cancel();
    }
    _newSessionsSubscription?.cancel();
    super.dispose();
  }

  List<WorkoutSession> _computeFilteredSessions(
    Iterable<WorkoutSession> sessions,
  ) {
    return sessions.where((session) {
      // Available Sessions should only include sessions with open spots
      // and that the user has not already joined.
      final isJoined =
          session.isUserJoined ?? _userJoinedSessionIds.contains(session.id);
      if (session.isFull || isJoined) {
        return false;
      }

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

      // Filter by gym
      if (_filterGymId != null && session.gymId != _filterGymId) {
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
      if (_filterDuration != null && session.durationMinutes != _filterDuration) {
        return false;
      }

      return true;
    }).toList();
  }

  void _mergeJoinedFlagsFromSessions(Iterable<WorkoutSession> sessions) {
    // Only apply non-null join flags; if a payload omits `is_user_joined`,
    // keep the last known state to avoid UI flicker.
    for (final session in sessions) {
      final flag = session.isUserJoined;
      if (flag == null) continue;
      if (flag) {
        _userJoinedSessionIds.add(session.id);
      } else {
        _userJoinedSessionIds.remove(session.id);
      }
    }
  }

  /// Subscribe to specific visible sessions only (not all sessions)
  void _subscribeToVisibleSessions() {
    // Get currently visible session IDs
    final visibleSessionIds = _filteredSessions.map((s) => s.id).toSet();

    // Cancel subscriptions for sessions no longer visible
    final sessionsToUnsubscribe = _sessionSubscriptions.keys
        .where((id) => !visibleSessionIds.contains(id))
        .toList();

    for (final sessionId in sessionsToUnsubscribe) {
      _sessionSubscriptions[sessionId]?.cancel();
      _sessionSubscriptions.remove(sessionId);
    }

    // Subscribe to newly visible sessions
    for (final session in _filteredSessions) {
      if (!_sessionSubscriptions.containsKey(session.id)) {
        _sessionSubscriptions[session.id] = _sessionService
            .subscribeToSession(session.id)
            .listen(
              (updatedSession) {
                if (updatedSession != null && mounted) {
                  setState(() {
                    // Update the session in the list
                    final index = _allSessions.indexWhere(
                      (s) => s.id == session.id,
                    );
                    if (index != -1) {
                      final existing = _allSessions[index];
                      _allSessions[index] = updatedSession.gym == null
                          ? updatedSession.copyWith(gym: existing.gym)
                          : updatedSession;
                      _mergeJoinedFlagsFromSessions([_allSessions[index]]);
                      _filteredSessions = _computeFilteredSessions(_allSessions);
                    }
                  });
                } else if (updatedSession == null && mounted) {
                  // Session was deleted/cancelled
                  setState(() {
                    _allSessions.removeWhere((s) => s.id == session.id);
                    _filteredSessions = _computeFilteredSessions(_allSessions);
                  });
                }
              },
              onError: (error) {
                debugPrint(
                  'Error in session subscription for ${session.id}: $error',
                );
              },
            );
      }
    }
  }

  /// Subscribe to recent upcoming sessions (top 15 by start time)
  /// This ensures we catch new sessions as they're created
  void _subscribeToRecentSessions() {
    _newSessionsSubscription = _sessionService
        .subscribeToSessions(gymId: _filterGymId)
        .listen(
          (sessions) {
            if (!mounted) return;

            // Skip processing during initial load to avoid duplicates
            if (_isInitialLoading) return;

            final upcomingSessions = sessions
                .where((s) => s.status == 'upcoming')
                .where((s) => s.startTime.isAfter(DateTime.now()))
                .toList()
              ..sort((a, b) => a.startTime.compareTo(b.startTime));

            final topSessions = upcomingSessions.take(15).toList();
            final topSessionIds = topSessions
                .map((s) => s.id)
                .toSet();

            // Check if we need to refresh the list
            final currentIds = _allSessions.map((s) => s.id).toSet();

            // New sessions that should be added
            final newSessionIds = topSessionIds.difference(currentIds);

            // Sessions that should be removed (no longer in top 15 or cancelled)
            final removedSessionIds = currentIds.difference(topSessionIds);

            if (newSessionIds.isNotEmpty || removedSessionIds.isNotEmpty) {
              setState(() {
                _allSessions = topSessions;
                _mergeJoinedFlagsFromSessions(_allSessions);
                _filteredSessions = _computeFilteredSessions(_allSessions);
              });
            } else {
              setState(() {
                _allSessions = topSessions;
                _mergeJoinedFlagsFromSessions(_allSessions);
                _filteredSessions = _computeFilteredSessions(_allSessions);
              });
            }

            if (removedSessionIds.isNotEmpty) {
              setState(() {
                for (final id in removedSessionIds) {
                  _sessionSubscriptions[id]?.cancel();
                  _sessionSubscriptions.remove(id);
                }
              });
            }

            // Subscribe to visible sessions
            _subscribeToVisibleSessions();
          },
          onError: (error) {
            debugPrint('Error in recent sessions subscription: $error');
          },
        );
  }

  Future<void> _refreshUser() async {
    try {
      final profile = await _userService.getCurrentUserProfile();
      if (profile != null && mounted) {
        setState(() {
          _currentUser = app_user.User.fromJson(profile);
        });
      }
    } catch (e) {
      // Silently fail - user data will be refreshed on next screen visit
    }
  }

  Future<void> _loadGyms() async {
    setState(() {
      _isLoadingGyms = true;
    });

    try {
      final gyms = await _gymService.getGyms();
      if (mounted) {
        setState(() {
          _gyms = gyms;
          _isLoadingGyms = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGyms = false;
        });
      }
    }
  }

  Future<List<WorkoutSession>> _fetchSessionsPage(
    int page, {
    bool forceRefresh = false,
  }) async {
    var sessions = await _sessionService.listSessions(
      gymId: _filterGymId,
      status: 'upcoming',
      limit: _sessionsPerPage,
      offset: page * _sessionsPerPage,
      forceRefresh: forceRefresh,
    );

    if (_filterIntensity != null) {
      sessions = sessions
          .where((s) => s.intensityLevel == _filterIntensity)
          .toList();
    }

    if (_filterDuration != null) {
      sessions = sessions
          .where((s) => s.durationMinutes == _filterDuration)
          .toList();
    }

    if (_femaleOnlyMode) {
      sessions = sessions.where((s) => s.womenOnly).toList();
    }

    // Available Sessions should only include sessions that are not full and
    // that the user has not already joined.
    return sessions.where((s) {
      final isJoined = s.isUserJoined ?? _userJoinedSessionIds.contains(s.id);
      return !s.isFull && !isJoined;
    }).toList();
  }

  Future<void> _reloadSessionsFromServer() async {
    setState(() {
      _isLoadingSessions = true;
      _sessionsError = null;
      _currentPage = 0;
    });

    try {
      final sessions = await _fetchSessionsPage(0, forceRefresh: true);
      if (!mounted) return;

      setState(() {
        _allSessions = sessions;
        _mergeJoinedFlagsFromSessions(_allSessions);
        _filteredSessions = _computeFilteredSessions(_allSessions);
        _isLoadingSessions = false;
        _isInitialLoading = false;
        _hasMoreSessions = sessions.length >= _sessionsPerPage;
      });
      _subscribeToVisibleSessions();
    } catch (e) {
      if (mounted) {
        setState(() {
          _sessionsError = e.toString();
          _isLoadingSessions = false;
          _isInitialLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreSessions() async {
    if (_isLoadingMore || !_hasMoreSessions) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final newSessions = await _fetchSessionsPage(nextPage);

      if (mounted) {
        setState(() {
          _allSessions.addAll(newSessions);
          _mergeJoinedFlagsFromSessions(newSessions);
          _filteredSessions = _computeFilteredSessions(_allSessions);
          _currentPage = nextPage;
          _hasMoreSessions = newSessions.length >= _sessionsPerPage;
          _isLoadingMore = false;
        });

        // Subscribe to the newly loaded sessions
        _subscribeToVisibleSessions();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  /// Initial load of sessions (one-time fetch)
  Future<void> _loadSessions() async {
    await _reloadSessionsFromServer();
  }

  void _clearFilters() {
    setState(() {
      _filterIntensity = null;
      _filterTimeRange = null;
      _filterDuration = null;
      _filterGymId = null;
      _filteredSessions = _computeFilteredSessions(_allSessions);
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
                        _filterDuration != null ||
                        _filterGymId != null)
                      TextButton(
                        onPressed: () async {
                          setModalState(() {
                            _clearFilters();
                          });
                          await _reloadSessionsFromServer();
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Clear All'),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Gym filter
                Text(
                  'Gym',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  key: ValueKey(_filterGymId ?? 'all'),
                  initialValue: _filterGymId,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All gyms'),
                    ),
                    ..._gyms.map(
                      (gym) => DropdownMenuItem<int?>(
                        value: gym.id,
                        child: Text(gym.name),
                      ),
                    ),
                  ],
                  onChanged: _isLoadingGyms
                      ? null
                      : (value) {
                          setModalState(() {
                            _filterGymId = value;
                          });
                        },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  dropdownColor: AppTheme.surface,
                  iconEnabledColor: AppTheme.textSecondary,
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
                    onPressed: () async {
                      await _reloadSessionsFromServer();
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
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
    String tempSelectedTime = _currentUser.preferredTime ?? 'morning';

    await showModalBottomSheet(
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
                  final isSelected = tempSelectedTime == time['value'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final newTime = time['value'] as String;
                        if (newTime == tempSelectedTime) return;

                        // Update local state immediately for visual feedback
                        setModalState(() {
                          tempSelectedTime = newTime;
                        });

                        try {
                          await _userService.updatePreferredTime(newTime);
                          if (!mounted) return;
                          // Refresh user data to update main UI
                          await _refreshUser();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Preferred time updated!'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        } catch (e) {
                          // Revert on error
                          setModalState(() {
                            tempSelectedTime =
                                _currentUser.preferredTime ?? 'morning';
                          });
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to update: $e'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? AppTheme.primaryGradient
                              : null,
                          color: isSelected ? null : AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : AppTheme.surfaceBorder,
                            width: isSelected ? 0 : 1,
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
                            AnimatedOpacity(
                              opacity: isSelected ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
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
                  'Hey, ${_currentUser.name.split(' ').first}! 👋',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 8),

                Text(
                  'Ready to crush\nworkouts together?',
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
    final isFemale = _currentUser.gender?.toLowerCase() == 'female';

    final logo = GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              'assets/images/liftco_logo.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'LiftCo',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    final bell = GlassCard(
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
    );

    if (!isFemale) {
      return Row(
        children: [
          logo,
          const Spacer(),
          bell,
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 390;

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  logo,
                  const Spacer(),
                  bell,
                ],
              ),
              const SizedBox(height: 10),
              GlassCard(
                padding: const EdgeInsets.all(12),
                borderRadius: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.female, color: AppTheme.textSecondary, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Women-only sessions filter',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: _buildWomenOnlyToggle()),
                  ],
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            logo,
            const Spacer(),
            bell,
            const SizedBox(width: 10),
            SizedBox(width: 230, child: _buildWomenOnlyToggle()),
          ],
        );
      },
    );
  }

  Widget _buildCompactStatsSection(BuildContext context) {
    final timeData = app_user.PreferredTime.values.firstWhere(
      (t) => t['value'] == _currentUser.preferredTime,
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
                value: '${_currentUser.reputationScore}',
                iconColor: AppTheme.warning,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCompactStatItem(
                icon: Icons.fitness_center,
                label: 'Level',
                value: _currentUser.experienceLevel != null
                    ? _currentUser.experienceLevel!
                          .split('_')
                          .map(
                            (word) => word[0].toUpperCase() + word.substring(1),
                          )
                          .join(' ')
                    : 'Beginner',
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

  Widget _buildWomenOnlyToggle() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final toggleWidth = constraints.maxWidth;
          final knobWidth = toggleWidth / 2;

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: _femaleOnlyMode ? knobWidth : 0,
                top: 0,
                bottom: 0,
                width: knobWidth,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: _femaleOnlyMode
                        ? LinearGradient(
                            colors: [Colors.pink[400]!, Colors.purple[500]!],
                          )
                        : AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryOrange.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        if (!_femaleOnlyMode) return;
                        setState(() {
                          _femaleOnlyMode = false;
                        });
                        await _reloadSessionsFromServer();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: _femaleOnlyMode
                                ? AppTheme.textSecondary
                                : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          child: const Text('All'),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        if (_femaleOnlyMode) return;
                        setState(() {
                          _femaleOnlyMode = true;
                        });
                        await _reloadSessionsFromServer();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: _femaleOnlyMode
                                ? Colors.white
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Women Only'),
                          ),
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

  Widget _buildCompactStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
            GlassCard(
              onTap: _isLoadingSessions
                  ? null
                  : () async {
                      setState(() {
                        _isLoadingSessions = true;
                        _sessionsError = null;
                      });
                      try {
                        await _reloadSessionsFromServer();
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isLoadingSessions = false;
                          });
                        }
                      }
                    },
              padding: const EdgeInsets.all(10),
              borderRadius: 14,
              child: _isLoadingSessions
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryPurple,
                      ),
                    )
                  : const Icon(
                      Icons.refresh,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
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
                          _filterDuration != null ||
                          _filterGymId != null)
                      ? AppTheme.primaryPurple.withValues(alpha: 0.2)
                      : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        (_filterIntensity != null ||
                            _filterTimeRange != null ||
                            _filterDuration != null ||
                            _filterGymId != null)
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
                              _filterDuration != null ||
                              _filterGymId != null)
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
                                _filterDuration != null ||
                                _filterGymId != null)
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
                const SizedBox(height: 8),
                TextButton(
                  onPressed: widget.onNavigateToGyms,
                  child: const Text('Create Session'),
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
                        _filterDuration != null ||
                        _filterGymId != null))
                  TextButton(
                    onPressed: () async {
                      _clearFilters();
                      await _reloadSessionsFromServer();
                    },
                    child: const Text('Clear Filters'),
                  ),
                if (_allSessions.isEmpty)
                  TextButton(
                    onPressed: widget.onNavigateToGyms,
                    child: const Text('Create Session'),
                  ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredSessions.length,
            itemBuilder: (context, index) {
              final session = _filteredSessions[index];
              final isJoined =
                  session.isUserJoined ?? _userJoinedSessionIds.contains(session.id);
              return _buildSessionCard(session, index, isJoined);
            },
          ),

        // Load more button
        if (_hasMoreSessions && !_isLoadingSessions)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator(
                      color: AppTheme.primaryPurple,
                    )
                  : TextButton.icon(
                      onPressed: _loadMoreSessions,
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Load More'),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _buildSessionCard(WorkoutSession session, int index, bool isJoined) {
    final hostName = session.host?['name'] as String? ?? 'Unknown';
    final hostPhotoUrl = session.host?['profile_photo_url'] as String?;

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
            // Host photo or session icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: hostPhotoUrl == null
                    ? AppTheme.primaryGradient
                    : null,
                borderRadius: BorderRadius.circular(10),
                image: hostPhotoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(hostPhotoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: hostPhotoUrl == null
                  ? const Center(
                      child: Icon(
                        Icons.fitness_center,
                        color: Colors.white,
                        size: 20,
                      ),
                    )
                  : null,
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
                  const SizedBox(height: 4),
                  // Host name row
                  Row(
                    children: [
                      Icon(Icons.person, color: AppTheme.textMuted, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        hostName,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Status tags row
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Gym name tag
                      if (session.gym != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            session.gym!['name'] ?? 'Unknown Gym',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      // Joined tag
                      if (isJoined)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: AppTheme.success,
                                size: 10,
                              ),
                              SizedBox(width: 2),
                              Text(
                                'Joined',
                                style: TextStyle(
                                  color: AppTheme.success,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Open tag
                      if (!isJoined && !session.isFull)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentCyan.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_open,
                                color: AppTheme.accentCyan,
                                size: 10,
                              ),
                              SizedBox(width: 2),
                              Text(
                                'Open',
                                style: TextStyle(
                                  color: AppTheme.accentCyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Women Only tag
                      if (session.isWomenOnly)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.pink[400]!, Colors.purple[500]!],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.female, color: Colors.white, size: 10),
                              SizedBox(width: 2),
                              Text(
                                'Women Only',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Date
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          session.formattedDate,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isJoined
                        ? AppTheme.success.withValues(alpha: 0.2)
                        : session.availableSpots > 2
                        ? AppTheme.success.withValues(alpha: 0.2)
                        : AppTheme.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isJoined ? 'Joined' : '${session.availableSpots} left',
                    style: TextStyle(
                      color: isJoined
                          ? AppTheme.success
                          : session.availableSpots > 2
                          ? AppTheme.success
                          : AppTheme.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.sessionType,
                  style: const TextStyle(
                    color: AppTheme.accentCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (300 + index * 50).ms);
  }
}
