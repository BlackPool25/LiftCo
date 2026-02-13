// lib/screens/schedule_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../models/workout_session.dart';
import '../services/current_user_resolver.dart';
import '../services/session_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import 'create_session_screen.dart';
import 'session_details_screen.dart';

/// Schedule screen - shows upcoming sessions
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late SessionService _sessionService;
  List<WorkoutSession> _sessions = [];
  bool _isLoading = true;
  String? _error;
  String? _currentAppUserId;

  // Realtime subscription
  StreamSubscription<List<WorkoutSession>>? _sessionsSubscription;

  @override
  void initState() {
    super.initState();
    _sessionService = SessionService(Supabase.instance.client);
    _loadCurrentAppUserId();
    _subscribeToUserSessions();
  }

  Future<void> _loadCurrentAppUserId() async {
    final appUserId = await CurrentUserResolver.resolveAppUserId(
      Supabase.instance.client,
    );
    if (!mounted) return;
    setState(() {
      _currentAppUserId = appUserId;
    });
  }

  @override
  void dispose() {
    _sessionsSubscription?.cancel();
    super.dispose();
  }

  /// Subscribe only to user's joined sessions
  void _subscribeToUserSessions() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _sessionsSubscription = _sessionService.subscribeToUserSessions().listen(
      (sessions) {
        if (mounted) {
          setState(() {
            _sessions = sessions;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _error = error.toString();
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _leaveSession(String sessionId) async {
    try {
      await _sessionService.leaveSession(sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Left session successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
        // No need to reload - realtime will update automatically
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave session: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  /// Manual refresh - re-subscribes to get latest data
  Future<void> _refresh() async {
    _sessionsSubscription?.cancel();
    _subscribeToUserSessions();
  }

  void _navigateToSessionDetails(WorkoutSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionDetailsScreen(session: session),
      ),
    ).then((_) {
      _refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Schedule',
              style: Theme.of(context).textTheme.headlineLarge,
            ).animate().fadeIn().slideY(begin: -0.2),
            const SizedBox(height: 8),
            Text(
              'Manage your upcoming sessions',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),

            // Stats summary
            if (_sessions.isNotEmpty && !_isLoading)
              _buildStatsSummary().animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 24),

            // Sessions list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryPurple,
                      ),
                    )
                  : _error != null
                  ? _buildErrorState()
                  : _sessions.isEmpty
                  ? _buildEmptyState()
                  : _buildSessionsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    final upcomingCount = _sessions.where((s) => s.isUpcoming).length;
    final todayCount = _sessions.where((s) {
      final now = DateTime.now();
      return s.startTime.year == now.year &&
          s.startTime.month == now.month &&
          s.startTime.day == now.day;
    }).length;

    return Row(
      children: [
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 16,
            child: Column(
              children: [
                Text(
                  '$upcomingCount',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Upcoming',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: 16,
            child: Column(
              children: [
                Text(
                  '$todayCount',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Today',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionsList() {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primaryPurple,
      backgroundColor: AppTheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          final session = _sessions[index];
          return _buildSessionCard(session, index);
        },
      ),
    );
  }

  Widget _buildSessionCard(WorkoutSession session, int index) {
    final isHost = session.hostUserId == _currentAppUserId;

    return Dismissible(
      key: Key(session.id),
      direction: isHost ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.exit_to_app, color: AppTheme.error),
            SizedBox(width: 8),
            Text(
              'Leave Session',
              style: TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => _leaveSession(session.id),
      confirmDismiss: (_) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text('Leave Session?'),
            content: const Text(
              'Are you sure you want to leave this workout session?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _navigateToSessionDetails(session),
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.title,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (session.gym != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: AppTheme.textMuted,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  session.gym!['name'] ?? 'Unknown Gym',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              session.sessionType,
                              style: const TextStyle(
                                color: AppTheme.accentCyan,
                                fontSize: 13,
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
                                    colors: [
                                      Colors.pink[400]!,
                                      Colors.purple[500]!,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.female,
                                      color: Colors.white,
                                      size: 10,
                                    ),
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
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Host badge or status
                  if (isHost)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            color: AppTheme.primaryPurple,
                            size: 12,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Host',
                            style: TextStyle(
                              color: AppTheme.primaryPurple,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: AppTheme.surfaceBorder, height: 1),
              const SizedBox(height: 12),
              // Time and date
              Row(
                children: [
                  _buildSessionDetail(
                    Icons.calendar_today_outlined,
                    session.formattedDate,
                  ),
                  const SizedBox(width: 20),
                  _buildSessionDetail(Icons.access_time, session.formattedTime),
                  const SizedBox(width: 20),
                  _buildSessionDetail(Icons.timelapse, session.durationText),
                ],
              ),
              const SizedBox(height: 8),
              // Spots info
              Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    color: AppTheme.textMuted,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${session.currentCount}/${session.maxCapacity} members',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (200 + index * 50).ms).slideY(begin: 0.1);
  }

  Widget _buildSessionDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.textMuted, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: GlassCard(
        padding: const EdgeInsets.all(32),
        borderRadius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Failed to load sessions',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An error occurred',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GradientButton(
              text: 'Retry',
              onPressed: _refresh,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: GlassCard(
        padding: const EdgeInsets.all(32),
        borderRadius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                color: AppTheme.textMuted,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No sessions yet',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Join or create a workout session\nto get started',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Create Session',
              icon: Icons.add,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateSessionScreen(),
                  ),
                ).then((_) => _refresh());
              },
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ],
        ),
      ),
    );
  }
}
