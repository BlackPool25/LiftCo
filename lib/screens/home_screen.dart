// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth_bloc.dart';
import '../config/theme.dart';
import '../models/user.dart' as app_user;
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

class HomeScreen extends StatelessWidget {
  final app_user.User user;

  const HomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.surfaceGradient,
        ),
        child: Stack(
          children: [
            // Background gradient orbs
            _buildBackgroundOrbs(),
            
            // Main content
            SafeArea(
              child: CustomScrollView(
                slivers: [
                  // App Bar
                  SliverToBoxAdapter(
                    child: _buildAppBar(context)
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .slideY(begin: -0.2, end: 0),
                  ),

                  // Feature Card (like the Main Wallet card)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: _buildFeatureCard(context)
                          .animate()
                          .fadeIn(delay: 100.ms, duration: 500.ms)
                          .slideY(begin: 0.1, end: 0),
                    ),
                  ),

                  // Quick Actions Grid
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildQuickActions(context)
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 500.ms),
                    ),
                  ),

                  // Stats Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _buildStatsSection(context)
                          .animate()
                          .fadeIn(delay: 300.ms, duration: 500.ms),
                    ),
                  ),

                  // Upcoming Sessions
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildSessionsSection(context)
                          .animate()
                          .fadeIn(delay: 400.ms, duration: 500.ms),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ],
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
          onPressed: () {
            // TODO: Navigate to create session
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'New Session',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
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
                  AppTheme.primaryPurple.withValues(alpha: 0.2),
                  AppTheme.primaryPurple.withValues(alpha: 0),
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

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
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
                    decoration: const BoxDecoration(
                      color: AppTheme.accentCyan,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Profile button with sign out
          GlassCard(
            padding: const EdgeInsets.all(12),
            borderRadius: 14,
            onTap: () {
              context.read<AuthBloc>().add(SignOutRequested());
            },
            child: const Icon(
              Icons.logout_rounded,
              color: AppTheme.textPrimary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context) {
    return FeatureCard(
      gradientColors: const [
        Color(0xFF2D1B69),
        Color(0xFF1E3A5F),
        Color(0xFF0F2847),
      ],
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Hey, ${user.name.split(' ').first}! 👋',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: AppTheme.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${user.reputationScore}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Ready to crush\nyour workout?',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  height: 1.2,
                ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              GradientButton(
                text: 'Find Buddy',
                icon: Icons.search,
                onPressed: () {},
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                gradientColors: [
                  Colors.white,
                  Colors.white.withValues(alpha: 0.9),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionChip(
                icon: Icons.location_on_outlined,
                label: 'Nearby Gyms',
                onTap: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionChip(
                icon: Icons.calendar_today_outlined,
                label: 'Schedule',
                onTap: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionChip(
                icon: Icons.people_outline,
                label: 'Buddies',
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      borderRadius: 16,
      child: Column(
        children: [
          Icon(icon, color: AppTheme.accentCyan, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    // Get preferred time data
    final timeData = app_user.PreferredTime.values.firstWhere(
      (t) => t['value'] == user.preferredTime,
      orElse: () => app_user.PreferredTime.values[1],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Stats',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.emoji_events_outlined,
                label: 'Reputation',
                value: '${user.reputationScore}',
                iconColor: AppTheme.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.fitness_center,
                label: 'Level',
                value: user.experienceLevel != null
                    ? user.experienceLevel!.substring(0, 1).toUpperCase() +
                        user.experienceLevel!.substring(1)
                    : 'Beginner',
                iconColor: AppTheme.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Preferred time card
        GlassCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 20,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color((timeData['gradient'] as List)[0]),
                      Color((timeData['gradient'] as List)[1]),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  timeData['icon'] as IconData,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preferred Time',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${timeData['label']}',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${timeData['time']}',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Upcoming Sessions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            TextButton(
              onPressed: () {},
              child: const Text(
                'See all',
                style: TextStyle(
                  color: AppTheme.accentCyan,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Empty state
        GlassCard(
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
                'Join or create a workout session\nto get started',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GradientButton(
                text: 'Create Session',
                icon: Icons.add,
                onPressed: () {},
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
