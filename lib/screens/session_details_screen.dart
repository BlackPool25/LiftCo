// lib/screens/session_details_screen.dart
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

class SessionDetailsScreen extends StatefulWidget {
  final WorkoutSession session;

  const SessionDetailsScreen({super.key, required this.session});

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  late SessionService _sessionService;
  WorkoutSession? _session;
  bool _isJoining = false;
  bool _isRefreshing = false;
  String? _currentUserId;
  bool _isUserJoined = false;
  bool _membershipChecked = false;

  // Realtime subscription for this specific session
  StreamSubscription<WorkoutSession?>? _sessionSubscription;
  StreamSubscription<List<dynamic>>? _membersSubscription;

  @override
  void initState() {
    super.initState();
    _sessionService = SessionService(Supabase.instance.client);
    _session = widget.session;
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _getCurrentUser();
    await _loadSessionDetails();

    if (!mounted) return;
    setState(() {
      _membershipChecked = true;
    });

    _subscribeToSession();
    _subscribeToMembers();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _membersSubscription?.cancel();
    super.dispose();
  }

  /// Subscribe to this specific session's changes
  void _subscribeToSession() {
    _sessionSubscription = _sessionService
        .subscribeToSession(_session!.id)
        .listen(
          (updatedSession) {
            if (updatedSession != null && mounted) {
              setState(() {
                _session = updatedSession;
                _checkIfUserJoined();
              });
            } else if (updatedSession == null && mounted) {
              // Session was deleted/cancelled - show message and pop
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('This session has been cancelled'),
                  backgroundColor: AppTheme.error,
                ),
              );
              Navigator.pop(context);
            }
          },
          onError: (error) {
            debugPrint('Error in session subscription: $error');
          },
        );
  }

  /// Subscribe to members changes for this session
  void _subscribeToMembers() {
    _membersSubscription = _sessionService
        .subscribeToSessionMembers(_session!.id)
        .listen(
          (members) async {
            // Fetch full session details with updated members
            try {
              final updatedSession = await _sessionService.getSession(
                _session!.id,
              );
              if (updatedSession != null && mounted) {
                setState(() {
                  _session = updatedSession;
                  _checkIfUserJoined();
                });
              }
            } catch (e) {
              debugPrint('Error fetching updated session: $e');
            }
          },
          onError: (error) {
            debugPrint('Error in members subscription: $error');
          },
        );
  }

  Future<void> _getCurrentUser() async {
    final appUserId = await CurrentUserResolver.resolveAppUserId(
      Supabase.instance.client,
    );
    if (appUserId != null) {
      setState(() {
        _currentUserId = appUserId;
        _checkIfUserJoined();
      });
    }
  }

  void _checkIfUserJoined() {
    if (_session?.members != null && _currentUserId != null) {
      _isUserJoined = _session!.members!.any(
        (m) => m.userId == _currentUserId && m.status == 'joined',
      );
    }
  }

  Future<void> _loadSessionDetails() async {
    try {
      final session = await _sessionService.getSession(_session!.id);
      if (session != null && mounted) {
        setState(() {
          _session = session;
          _checkIfUserJoined();
        });
      }
    } catch (e) {
      debugPrint('Error loading session details: $e');
    }
  }

  Future<void> _joinSession() async {
    setState(() {
      _isJoining = true;
    });

    try {
      await _sessionService.joinSession(_session!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined the session!'),
            backgroundColor: AppTheme.success,
          ),
        );
        // Reload session to show updated member list and count
        await _loadSessionDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  Future<void> _leaveSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Leave Session?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to leave this workout session?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isJoining = true;
    });

    try {
      await _sessionService.leaveSession(_session!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have left the session'),
            backgroundColor: AppTheme.textSecondary,
          ),
        );
        // Reload session to show updated member list and count
        await _loadSessionDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  Future<void> _cancelSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancel Session?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'This will cancel the session for all members. Are you sure?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Session'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Cancel Session'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isJoining = true;
    });

    try {
      await _sessionService.cancelSession(_session!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session cancelled successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  void _showJoinConfirmation() {
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.fitness_center,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Join this session?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'You\'re about to join "${_session!.title}" at ${_session!.formattedTime}',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_session!.availableSpots} spots remaining',
                style: const TextStyle(
                  color: AppTheme.success,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    onTap: () => Navigator.pop(context),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    borderRadius: 16,
                    child: const Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GradientButton(
                    text: 'Confirm Join',
                    isLoading: _isJoining,
                    onPressed: () {
                      Navigator.pop(context);
                      _joinSession();
                    },
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  bool get _isHost {
    if (_session == null || _currentUserId == null) return false;
    return _session!.hostUserId == _currentUserId;
  }

  bool get _canJoin {
    if (_session == null) return false;
    if (_isUserJoined) return false;
    if (_session!.isFull) return false;
    if (!_session!.isUpcoming) return false;
    if (_session!.isCancelled) return false;
    return true;
  }

  bool get _canLeave {
    if (_session == null) return false;
    if (!_isUserJoined) return false;
    if (_isHost) return false;
    if (!_session!.isUpcoming) return false;
    return true;
  }

  bool get _canCancel {
    if (_session == null) return false;
    if (!_isHost) return false;
    if (!_session!.isUpcoming) return false;
    if (_session!.isCancelled) return false;
    return true;
  }

  bool get _canViewOtherMembers => _isHost || _isUserJoined;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
                    // App bar
                    SliverToBoxAdapter(child: _buildAppBar()),

                    // Session info card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: _buildSessionInfoCard(),
                      ),
                    ),

                    // Members section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Members (${_session?.currentCount ?? 0}/${_session?.maxCapacity ?? 0})',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // Members list (visible only to joined members or host)
                    if (_canViewOtherMembers)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final joinedMembers = _session?.members
                                    ?.where((m) => m.status == 'joined')
                                    .toList() ??
                                [];
                            if (index >= joinedMembers.length) return null;
                            return _buildMemberCard(joinedMembers[index], index);
                          },
                              childCount: _session?.members
                                      ?.where((m) => m.status == 'joined')
                                      .length ??
                                  0),
                        ),
                      )
                    else
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: GlassCard(
                            padding: const EdgeInsets.all(16),
                            borderRadius: 14,
                            child: const Text(
                              'Join to see other members info',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
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
              'Session Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          GlassCard(
            onTap: _isRefreshing
                ? null
                : () async {
                    setState(() {
                      _isRefreshing = true;
                    });
                    try {
                      await _loadSessionDetails();
                      await _getCurrentUser();
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isRefreshing = false;
                        });
                      }
                    }
                  },
            padding: const EdgeInsets.all(12),
            borderRadius: 14,
            child: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryPurple,
                    ),
                  )
                : const Icon(
                    Icons.refresh,
                    color: AppTheme.textPrimary,
                    size: 20,
                  ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildSessionInfoCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session type badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _session?.sessionType ?? 'Workout',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor().withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _session?.status ?? 'unknown',
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Title
          Text(
            _session?.title ?? 'Untitled Session',
            style: Theme.of(context).textTheme.headlineSmall,
          ),

          // Joined indicator (shown near the top of the session)
          if (_isUserJoined) ...[
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderRadius: 16,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'You\'ve Joined',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Description
          if (_session?.description != null &&
              _session!.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _session!.description!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],

          const SizedBox(height: 20),
          const Divider(color: AppTheme.surfaceBorder, height: 1),
          const SizedBox(height: 20),

          // Gym Info
          if (_session?.gym != null) ...[
            _buildInfoRow(
              Icons.location_on_outlined,
              _session!.gym!['name'] ?? 'Unknown Gym',
            ),
            const SizedBox(height: 12),
          ],

          // Date & Time
          _buildInfoRow(
            Icons.calendar_today_outlined,
            _session?.formattedDate ?? 'Unknown date',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.access_time,
            _session?.formattedTime ?? 'Unknown time',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.timelapse,
            'Duration: ${_session?.durationText ?? "Unknown"}',
          ),

          // Intensity
          if (_session?.intensityLevel != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.speed,
              'Intensity: ${_session!.intensityLevel}',
            ),
          ],

          const SizedBox(height: 16),
          const Divider(color: AppTheme.surfaceBorder, height: 1),
          const SizedBox(height: 16),

          // Host info
          Row(
            children: [
              _buildAvatarWidget(
                name: _session?.host?['name'] ?? 'U',
                photoUrl: _session?.host?['profile_photo_url'] as String?,
                size: 44,
                isHost: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Host',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: Colors.white, size: 10),
                              SizedBox(width: 2),
                              Text('HOST', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _session?.host?['name'] ?? 'Unknown',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_session?.host?['age'] != null)
                      Text(
                        '${_session!.host!['age']} yrs',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              // Spots remaining
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (_session?.availableSpots ?? 0) > 0
                      ? AppTheme.success.withValues(alpha: 0.2)
                      : AppTheme.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_session?.availableSpots ?? 0} spots left',
                  style: TextStyle(
                    color: (_session?.availableSpots ?? 0) > 0
                        ? AppTheme.success
                        : AppTheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
  }

  Color _getStatusColor() {
    switch (_session?.status) {
      case 'upcoming':
        return AppTheme.accentCyan;
      case 'in_progress':
        return AppTheme.warning;
      case 'finished':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.error;
      default:
        return AppTheme.textMuted;
    }
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accentCyan, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ),
      ],
    );
  }

  /// Builds an avatar widget with profile photo or initials fallback
  Widget _buildAvatarWidget({
    required String name,
    String? photoUrl,
    double size = 44,
    bool isHost = false,
    bool isCurrentUser = false,
  }) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size / 3),
          border: Border.all(
            color: isHost
                ? AppTheme.primaryPurple
                : isCurrentUser
                    ? AppTheme.accentCyan
                    : AppTheme.surfaceBorder,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size / 3 - 1),
          child: Image.network(
            photoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) =>
                _buildInitialsAvatar(name, size, isHost),
          ),
        ),
      );
    }
    return _buildInitialsAvatar(name, size, isHost);
  }

  Widget _buildInitialsAvatar(String name, double size, bool isHost) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: isHost ? AppTheme.primaryGradient : AppTheme.accentGradient,
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.38,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(SessionMember member, int index) {
    final isHost = member.userId == _session?.hostUserId;
    final isCurrentUser = member.userId == _currentUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderRadius: 14,
        child: Row(
          children: [
            // Profile photo avatar
            _buildAvatarWidget(
              name: member.user?['name'] ?? 'U',
              photoUrl: member.profilePhotoUrl,
              size: 44,
              isHost: isHost,
              isCurrentUser: isCurrentUser,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          member.user?['name'] ?? 'Unknown',
                          style: TextStyle(
                            color: isCurrentUser
                                ? AppTheme.accentCyan
                                : AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isHost) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: Colors.white, size: 10),
                              SizedBox(width: 2),
                              Text(
                                'HOST',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentCyan.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              color: AppTheme.accentCyan,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Joined ${_formatJoinedTime(member.joinedAt)}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      if (member.age != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppTheme.textMuted,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${member.age} yrs',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (200 + index * 50).ms);
  }

  String _formatJoinedTime(DateTime joinedAt) {
    final now = DateTime.now();
    final diff = now.difference(joinedAt);

    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Widget? _buildBottomBar() {
    if (!_membershipChecked) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
        ),
        child: SafeArea(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 16),
            borderRadius: 16,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryPurple,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Host can cancel session
    if (_canCancel) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isUserJoined)
                GlassCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  borderRadius: 16,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: AppTheme.success,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'You\'ve Joined',
                        style: TextStyle(
                          color: AppTheme.success,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isUserJoined) const SizedBox(height: 12),
              GlassCard(
                onTap: _cancelSession,
                padding: const EdgeInsets.symmetric(vertical: 16),
                borderRadius: 16,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel, color: AppTheme.error, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Cancel Session',
                      style: TextStyle(
                        color: AppTheme.error,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Members can leave session
    if (_isUserJoined && _canLeave) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
        ),
        child: SafeArea(
          child: GlassCard(
            onTap: _leaveSession,
            padding: const EdgeInsets.symmetric(vertical: 16),
            borderRadius: 18,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.exit_to_app, color: AppTheme.error, size: 20),
                SizedBox(width: 8),
                Text(
                  'Leave Session',
                  style: TextStyle(
                    color: AppTheme.error,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Already joined but can't leave (shouldn't happen, but handle it)
    if (_isUserJoined) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
        ),
        child: SafeArea(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 16),
            borderRadius: 16,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                SizedBox(width: 8),
                Text(
                  'Already Joined',
                  style: TextStyle(
                    color: AppTheme.success,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Can join session
    if (_canJoin) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
        ),
        child: SafeArea(
          child: GradientButton(
            text: 'Join Session',
            icon: Icons.person_add,
            isLoading: _isJoining,
            onPressed: _showJoinConfirmation,
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
        ),
      );
    }

    // Session is full
    if (_session?.isFull == true) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
        ),
        child: SafeArea(
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 16),
            borderRadius: 16,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, color: AppTheme.textMuted, size: 20),
                SizedBox(width: 8),
                Text(
                  'Session Full',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return null;
  }
}
