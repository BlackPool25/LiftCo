// lib/screens/gym_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../models/gym.dart';
import '../models/workout_session.dart';
import '../services/current_user_resolver.dart';
import '../services/gym_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import 'create_session_screen.dart';
import 'session_details_screen.dart';

class GymDetailsScreen extends StatefulWidget {
  final Gym gym;

  const GymDetailsScreen({super.key, required this.gym});

  @override
  State<GymDetailsScreen> createState() => _GymDetailsScreenState();
}

class _GymDetailsScreenState extends State<GymDetailsScreen> {
  late GymService _gymService;
  List<WorkoutSession> _sessions = [];
  List<WorkoutSession> _filteredSessions = [];
  bool _isLoading = true;
  String? _error;
  bool _femaleOnlyMode = false;
  String? _currentUserGender;

  @override
  void initState() {
    super.initState();
    _gymService = GymService(Supabase.instance.client);
    _loadCurrentUserGender();
    _loadSessions();
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

  void _applyFilter() {
    setState(() {
      if (_femaleOnlyMode) {
        _filteredSessions = _sessions.where((s) => s.isWomenOnly).toList();
      } else {
        _filteredSessions = _sessions;
      }
    });
  }

  Future<void> _loadSessions({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sessions = await _gymService.getGymSessions(
        widget.gym.id,
        forceRefresh: forceRefresh,
      );
      setState(() {
        _sessions = sessions;
        _filteredSessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateToCreateSession() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateSessionScreen(gym: widget.gym),
      ),
    ).then((created) {
      if (created == true) {
        _loadSessions(forceRefresh: true);
      }
    });
  }

  void _navigateToSessionDetails(WorkoutSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionDetailsScreen(session: session),
      ),
    ).then((joined) {
      if (joined == true) {
        _loadSessions(forceRefresh: true);
      }
    });
  }

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

              // Gym info card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: _buildGymInfoCard(),
                ),
              ),

              // Sessions section header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Available Sessions',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          GlassCard(
                            onTap: _isLoading
                                ? null
                                : () => _loadSessions(forceRefresh: true),
                            padding: const EdgeInsets.all(10),
                            borderRadius: 14,
                            child: _isLoading
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
                        ],
                      ),

                      // Female-only mode toggle (full-width row on phones for easier tapping)
                      if (_currentUserGender?.toLowerCase() == 'female') ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: _buildWomenOnlyToggle(),
                        ),
                      ],
                      if (_filteredSessions.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${_filteredSessions.length} sessions',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Sessions list
              _isLoading
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryPurple,
                          ),
                        ),
                      ),
                    )
                  : _error != null
                  ? SliverToBoxAdapter(child: _buildErrorState())
                  : _filteredSessions.isEmpty
                  ? SliverToBoxAdapter(child: _buildEmptyState())
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return _buildSessionCard(
                            _filteredSessions[index],
                            index,
                          );
                        }, childCount: _filteredSessions.length),
                      ),
                    ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPurple.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _navigateToCreateSession,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Create Session',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
              widget.gym.name,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildGymInfoCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gym image placeholder
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryPurple.withValues(alpha: 0.3),
                  AppTheme.accentCyan.withValues(alpha: 0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(
                Icons.fitness_center,
                color: AppTheme.textSecondary,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Gym name
          Text(
            widget.gym.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),

          // Address
          _buildInfoRow(
            Icons.location_on_outlined,
            widget.gym.formattedAddress,
          ),
          const SizedBox(height: 8),

          // Hours
          _buildInfoRow(Icons.access_time, widget.gym.formattedHours),

          // Contact info
          if (widget.gym.phone != null || widget.gym.email != null) ...[
            const SizedBox(height: 12),
            const Divider(color: AppTheme.surfaceBorder),
            const SizedBox(height: 12),
            if (widget.gym.phone != null)
              _buildInfoRow(Icons.phone_outlined, widget.gym.phone!),
            if (widget.gym.email != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.email_outlined, widget.gym.email!),
            ],
          ],

          // Amenities
          if (widget.gym.amenities != null &&
              widget.gym.amenities!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Amenities',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.gym.amenities!.map((amenity) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    amenity,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
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

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
          const SizedBox(height: 16),
          Text(
            'Failed to load sessions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadSessions, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: GlassCard(
        padding: const EdgeInsets.all(32),
        borderRadius: 24,
        child: Column(
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
              'Be the first to create a workout session!',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GradientButton(
              text: 'Create Session',
              icon: Icons.add,
              onPressed: _navigateToCreateSession,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(WorkoutSession session, int index) {
    return GlassCard(
      onTap: () => _navigateToSessionDetails(session),
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Session type icon
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

              // Session info
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

              // Spots available
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: session.availableSpots > 2
                      ? AppTheme.success.withValues(alpha: 0.2)
                      : AppTheme.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${session.availableSpots} spots left',
                  style: TextStyle(
                    color: session.availableSpots > 2
                        ? AppTheme.success
                        : AppTheme.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
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

          // Host info
          if (session.host != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  color: AppTheme.textMuted,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Host: ${session.host!['name'] ?? 'Unknown'}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: (200 + index * 50).ms).slideY(begin: 0.1);
  }

  Widget _buildWomenOnlyToggle() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(22),
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
                    borderRadius: BorderRadius.circular(18),
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
                      onTap: () {
                        if (!_femaleOnlyMode) return;
                        setState(() {
                          _femaleOnlyMode = false;
                          _applyFilter();
                        });
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
                            fontSize: 13,
                          ),
                          child: const Text('All'),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_femaleOnlyMode) return;
                        setState(() {
                          _femaleOnlyMode = true;
                          _applyFilter();
                        });
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
}
