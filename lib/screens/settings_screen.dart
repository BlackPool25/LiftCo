// lib/screens/settings_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../blocs/auth_bloc.dart';
import '../config/theme.dart';
import '../models/user.dart' as app_user;
import '../services/notification_service.dart';
import '../widgets/glass_card.dart';

/// Settings screen - profile and app settings
class SettingsScreen extends StatefulWidget {
  final app_user.User user;

  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late NotificationService _notificationService;
  bool _notificationsEnabled = false;
  bool _isLoading = false;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService(Supabase.instance.client);
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    try {
      final status = await _notificationService.getCurrentDeviceStatus();
      setState(() {
        _notificationsEnabled = status['enabled'] as bool;
        _fcmToken = status['token'] as String?;
      });
    } catch (e) {
      debugPrint('Failed to check notification status: $e');
      setState(() {
        _notificationsEnabled = false;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _isLoading = true;
    });

    // Store scaffold messenger before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      if (value) {
        final enabled = await _notificationService
            .requestPermissionAndEnableCurrentDevice();
        final status = await _notificationService.getCurrentDeviceStatus();

        if (!mounted) return;

        if (!enabled || !(status['enabled'] as bool? ?? false)) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to enable notifications on this device. Please check app permissions and try again.',
              ),
              backgroundColor: AppTheme.error,
            ),
          );
          return;
        }

        if (!mounted) return;

        setState(() {
          _notificationsEnabled = true;
          _fcmToken = status['token'] as String?;
        });

        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Notifications enabled successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        final status = await _notificationService.getCurrentDeviceStatus();
        final token = status['token'] as String?;
        if (token != null) {
          await _notificationService.disableNotifications(token);
        }

        if (!mounted) return;

        setState(() {
          _notificationsEnabled = false;
        });

        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Notifications disabled'),
            backgroundColor: AppTheme.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      final message = e.toString();
      final isWebPushAbort =
          kIsWeb &&
          (message.toLowerCase().contains('abort') ||
              message.toLowerCase().contains('registration failed'));

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            isWebPushAbort
                ? 'Web push setup failed. Configure web push and try again.'
                : 'Failed to update notifications: $e',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineLarge,
            ).animate().fadeIn().slideY(begin: -0.2),
            const SizedBox(height: 32),

            // Profile section
            GlassCard(
              padding: const EdgeInsets.all(20),
              borderRadius: 20,
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        widget.user.name.isNotEmpty
                            ? widget.user.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.user.email ??
                              widget.user.phoneNumber ??
                              'No contact info',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

            const SizedBox(height: 24),

            // Settings options
            _buildSettingsGroup(context, 'Account', [
              _SettingsItem(
                icon: Icons.person_outline,
                title: 'Edit Profile',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.lock_outline,
                title: 'Privacy',
                onTap: () {},
              ),
            ]).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

            const SizedBox(height: 24),

            // Notifications toggle
            _buildNotificationsToggle()
                .animate()
                .fadeIn(delay: 250.ms)
                .slideY(begin: 0.1),

            const SizedBox(height: 24),

            _buildSettingsGroup(context, 'App', [
              _SettingsItem(
                icon: Icons.help_outline,
                title: 'Help & Support',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.info_outline,
                title: 'About',
                onTap: () {},
              ),
            ]).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

            const SizedBox(height: 32),

            // Sign out button
            GlassCard(
              onTap: () {
                context.read<AuthBloc>().add(SignOutRequested());
              },
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: AppTheme.error, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Sign Out',
                    style: TextStyle(
                      color: AppTheme.error,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notifications',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  color: _notificationsEnabled
                      ? AppTheme.success
                      : AppTheme.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Push Notifications',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _notificationsEnabled
                          ? 'Enabled - You will receive updates'
                          : 'Disabled - Enable to get updates',
                      style: TextStyle(
                        color: _notificationsEnabled
                            ? AppTheme.success
                            : AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryPurple,
                    ),
                  ),
                )
              else
                Switch.adaptive(
                  value: _notificationsEnabled,
                  onChanged: _toggleNotifications,
                  activeThumbColor: AppTheme.success,
                  activeTrackColor: AppTheme.success.withValues(alpha: 0.3),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsGroup(
    BuildContext context,
    String title,
    List<_SettingsItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: 16,
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  InkWell(
                    onTap: item.onTap,
                    borderRadius: BorderRadius.vertical(
                      top: index == 0 ? const Radius.circular(16) : Radius.zero,
                      bottom: index == items.length - 1
                          ? const Radius.circular(16)
                          : Radius.zero,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            color: AppTheme.textSecondary,
                            size: 22,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppTheme.textMuted,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (index < items.length - 1)
                    Divider(
                      height: 1,
                      color: AppTheme.surfaceBorder,
                      indent: 54,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}
