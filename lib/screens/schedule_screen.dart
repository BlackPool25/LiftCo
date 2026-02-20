// lib/screens/schedule_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/theme.dart';
import '../models/workout_session.dart';
import '../services/attendance_broadcast_coordinator.dart';
import '../services/current_user_resolver.dart';
import '../services/ibeacon_broadcaster.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../utils/chat_window.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import 'create_session_screen.dart';
import 'session_chat_screen.dart';
import 'session_details_screen.dart';

/// Schedule screen - shows upcoming sessions
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late SessionService _sessionService;
  final IBeaconBroadcaster _beaconBroadcaster = IBeaconBroadcaster();
  final AttendanceBroadcastCoordinator _broadcastCoordinator =
      AttendanceBroadcastCoordinator.instance;
  List<WorkoutSession> _sessions = [];
  bool _isLoading = true;
  String? _error;
  String? _currentAppUserId;

  RealtimeChannel? _attendanceChannel;
  String? _broadcastingSessionId;
  int _broadcastSecondsRemaining = 0;
  VoidCallback? _broadcastListener;

  // Realtime subscription
  StreamSubscription<List<WorkoutSession>>? _sessionsSubscription;

  @override
  void initState() {
    super.initState();
    _sessionService = SessionService(Supabase.instance.client);
    _broadcastListener = _onBroadcastStateChanged;
    _broadcastCoordinator.notifier.addListener(_broadcastListener!);
    _syncBroadcastState(_broadcastCoordinator.notifier.value);
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

    if (appUserId != null) {
      _subscribeToAttendance(appUserId);
    }
  }

  @override
  void dispose() {
    _sessionsSubscription?.cancel();
    if (_broadcastListener != null) {
      _broadcastCoordinator.notifier.removeListener(_broadcastListener!);
    }
    if (_attendanceChannel != null) {
      Supabase.instance.client.removeChannel(_attendanceChannel!);
      _attendanceChannel = null;
    }
    super.dispose();
  }

  void _onBroadcastStateChanged() {
    if (!mounted) return;
    _syncBroadcastState(_broadcastCoordinator.notifier.value);
  }

  void _syncBroadcastState(AttendanceBroadcastState state) {
    setState(() {
      _broadcastingSessionId = state.isBroadcasting ? state.sessionId : null;
      _broadcastSecondsRemaining =
          state.isBroadcasting ? state.secondsRemaining : 0;
    });
  }

  void _subscribeToAttendance(String appUserId) {
    // Single channel for all attendance inserts for this user.
    _attendanceChannel ??= Supabase.instance.client.channel(
      'attendance:$appUserId',
    );

    _attendanceChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'session_attendance',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: appUserId,
          ),
          callback: (payload) {
            try {
              final record = Map<String, dynamic>.from(payload.newRecord);
              final sessionId = record['session_id'] as String?;
              if (sessionId == null) return;

              if (!mounted) return;
              setState(() {
                _sessions = _sessions
                    .map(
                      (s) => s.id == sessionId
                          ? s.copyWith(attendanceMarked: true)
                          : s,
                    )
                    .toList();
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Attendance marked ✅'),
                  backgroundColor: AppTheme.success,
                ),
              );
            } catch (_) {
              // Ignore malformed realtime payloads.
            }
          },
        )
        .subscribe();
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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sessions = await _sessionService.getUserSessions(
        forceRefresh: true,
        includeInProgress: true,
      );
      if (!mounted) return;

      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your Schedule',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ).animate().fadeIn().slideY(begin: -0.2),
                ),
                const SizedBox(width: 12),
                GlassCard(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateSessionScreen(),
                      ),
                    ).then((created) {
                      if (created == true) {
                        _refresh();
                      }
                    });
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  borderRadius: 14,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add,
                        color: AppTheme.textPrimary,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Create',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
    final chatWindow = ChatWindowInfo.fromSession(session, DateTime.now());

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
                  const Spacer(),
                  _buildChatAccessChip(session, chatWindow),
                ],
              ),
              const SizedBox(height: 10),
              // Dedicated attendance row (keeps chips from cramping the same line)
              Align(
                alignment: Alignment.centerRight,
                child: _buildAttendanceChip(session),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (200 + index * 50).ms).slideY(begin: 0.1);
  }

  bool _isAttendanceWindowOpen(WorkoutSession session) {
    final now = DateTime.now();
    final opensAt = session.startTime.subtract(const Duration(minutes: 10));
    final closesAt = session.startTime.add(const Duration(minutes: 15));
    return !now.isBefore(opensAt) && !now.isAfter(closesAt);
  }

  bool _isAttendanceTooLate(WorkoutSession session) {
    final now = DateTime.now();
    final closesAt = session.startTime.add(const Duration(minutes: 15));
    return now.isAfter(closesAt);
  }

  Duration _attendanceOpensIn(WorkoutSession session) {
    final now = DateTime.now();
    final opensAt = session.startTime.subtract(const Duration(minutes: 10));
    return opensAt.difference(now);
  }

  Widget _buildAttendanceChip(WorkoutSession session) {
    final isBroadcasting = _broadcastingSessionId == session.id;
    final isMarked = session.attendanceMarked == true;
    final isOpen = _isAttendanceWindowOpen(session);
    final isTooLate = _isAttendanceTooLate(session);

    final enabled = !isBroadcasting && !isMarked && isOpen;

    IconData icon;
    Color iconColor;
    String label;

    if (isMarked) {
      icon = Icons.verified;
      iconColor = AppTheme.success;
      label = 'Marked';
    } else if (isBroadcasting) {
      icon = Icons.wifi_tethering;
      iconColor = AppTheme.primaryOrange;
      label = 'Broadcasting ${_broadcastSecondsRemaining}s';
    } else if (isTooLate) {
      icon = Icons.timer_off;
      iconColor = AppTheme.textMuted;
      label = 'Mark attendance';
    } else if (!isOpen) {
      icon = Icons.schedule;
      iconColor = AppTheme.textMuted;
      label = 'Mark attendance';
    } else {
      icon = Icons.check_circle_outline;
      iconColor = AppTheme.primaryOrange;
      label = 'Mark attendance';
    }

    return GlassCard(
      onTap: isBroadcasting
          ? null
          : () {
              if (enabled) {
                _markAttendance(session);
                return;
              }

              if (isMarked) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Attendance already marked ✅'),
                    backgroundColor: AppTheme.success,
                  ),
                );
                return;
              }

              if (isTooLate) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Too late to mark attendance'),
                    backgroundColor: AppTheme.error,
                  ),
                );
                return;
              }

              final opensIn = _attendanceOpensIn(session);
              final pretty = formatDurationCompact(opensIn);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Attendance opens in $pretty'),
                  backgroundColor: AppTheme.textSecondary,
                ),
              );
            },
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderRadius: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 14,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAttendance(WorkoutSession session) async {
    if (_broadcastCoordinator.notifier.value.isBroadcasting) return;

    // UI-side guard so we can show a clean message without a network request.
    if (session.attendanceMarked == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance already marked ✅'),
          backgroundColor: AppTheme.success,
        ),
      );
      return;
    }

    if (_isAttendanceTooLate(session)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Too late to mark attendance'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (!_isAttendanceWindowOpen(session)) {
      final pretty = formatDurationCompact(_attendanceOpensIn(session));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance opens in $pretty'),
          backgroundColor: AppTheme.textSecondary,
        ),
      );
      return;
    }

    // Ask for permissions early so users are prompted immediately.
    await _ensureBeaconPermissions();

    final support = await _beaconBroadcaster.getSupport();
    if (!support.isSupported) {
      throw Exception(support.details ?? 'Beacon broadcasting not supported');
    }
    if (!support.bluetoothOn) {
      throw Exception('Bluetooth is off');
    }
    if (!support.advertisingAvailable) {
      throw Exception('BLE advertising unavailable on this device');
    }

    try {
      final api = SupabaseService(Supabase.instance.client);
      final response = await api.post(
        'attendance-get-token',
        body: {'session_id': session.id},
      );

      debugPrint(
        '[attendance-get-token] session=${session.id} response=${response.keys.toList()} '
        'token_u32=${response['token_u32']} window_index=${response['window_index']}',
      );

      final beacon = response['ibeacon'] as Map<String, dynamic>?;
      if (beacon == null) {
        throw Exception('Invalid token response');
      }

      final proximityUuid = beacon['proximity_uuid'] as String?;
      final major = (beacon['major'] as num?)?.toInt();
      final minor = (beacon['minor'] as num?)?.toInt();

      debugPrint(
        '[ibeacon] uuid=$proximityUuid major=$major minor=$minor',
      );

      if (proximityUuid == null || major == null || minor == null) {
        throw Exception('Invalid beacon data');
      }

      const duration = Duration(seconds: 30);
      _broadcastCoordinator.start(sessionId: session.id, duration: duration);

      await _beaconBroadcaster.start(
        uuid: proximityUuid,
        major: major,
        minor: minor,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Broadcasting attendance token…'),
            backgroundColor: AppTheme.primaryOrange,
          ),
        );
      }

      await Future.delayed(duration);
      await _beaconBroadcaster.stop();
    } catch (e) {
      try {
        await _beaconBroadcaster.stop();
      } catch (_) {
        // ignore
      }

      _broadcastCoordinator.stop(sessionId: session.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      _broadcastCoordinator.stop(sessionId: session.id);
    }
  }

  Future<void> _ensureBeaconPermissions() async {
    // iOS: iBeacon APIs require location permission.
    // Android: Android 12+ requires explicit Bluetooth runtime permissions.
    final permissions = <Permission>[Permission.locationWhenInUse];

    if (Platform.isAndroid) {
      permissions.addAll([
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ]);
    } else if (Platform.isIOS) {
      // CoreBluetooth will still prompt on iOS; request it explicitly.
      permissions.add(Permission.bluetooth);
    }

    for (final p in permissions) {
      final status = await p.status;
      if (status.isGranted || status.isLimited) continue;

      final requested = await p.request();

      if (requested.isGranted || requested.isLimited) continue;

      if (!mounted) throw Exception('Permission required');

      final label = switch (p) {
        Permission.locationWhenInUse => 'Location',
        Permission.bluetooth => 'Bluetooth',
        Permission.bluetoothAdvertise => 'Bluetooth advertising',
        Permission.bluetoothScan => 'Bluetooth scanning',
        Permission.bluetoothConnect => 'Bluetooth connect',
        _ => 'Required',
      };

      // If the user permanently denied, guide them to Settings.
      if (requested.isPermanentlyDenied || requested.isRestricted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text(
              'Permission needed',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            content: Text(
              '$label permission is required to mark attendance.',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await openAppSettings();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }

      throw Exception('Permission denied: $label');
    }
  }

  Widget _buildChatAccessChip(WorkoutSession session, ChatWindowInfo window) {
    final isLocked = window.isLocked;
    final isClosed = window.isClosed;

    IconData icon;
    String label;
    Color iconColor;

    if (isLocked) {
      icon = Icons.lock;
      label = 'Chat opens in ${formatDurationCompact(window.opensAt.difference(DateTime.now()))}';
      iconColor = AppTheme.textMuted;
    } else if (isClosed) {
      icon = Icons.chat_bubble_outline;
      label = 'Chat (read-only)';
      iconColor = AppTheme.textSecondary;
    } else {
      icon = Icons.chat_bubble;
      label = 'Open Chat';
      iconColor = AppTheme.primaryOrange;
    }

    return GlassCard(
      onTap: isLocked
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SessionChatScreen(session: session),
                ),
              );
            },
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderRadius: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isLocked ? AppTheme.textMuted : AppTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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
