// lib/screens/main_shell.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../models/user.dart' as app_user;
import '../services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_tab.dart';
import 'gyms_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';

/// Main app shell with floating bottom navigation
class MainShell extends StatefulWidget {
  final app_user.User user;

  const MainShell({super.key, required this.user});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late final NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService(Supabase.instance.client);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptNotificationOptIn();
    });
  }

  Future<void> _maybePromptNotificationOptIn() async {
    final prefs = await SharedPreferences.getInstance();
    final promptKey = 'notif_prompted_${widget.user.id}';
    final alreadyPrompted = prefs.getBool(promptKey) ?? false;
    if (alreadyPrompted || !mounted) return;

    final status = await _notificationService.getCurrentDeviceStatus();
    if ((status['enabled'] as bool? ?? false) && mounted) {
      await prefs.setBool(promptKey, true);
      return;
    }
    if (!mounted) return;

    final shouldEnable = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Enable Notifications?'),
        content: const Text(
          'Get alerts when members join/leave and reminders before your sessions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    await prefs.setBool(promptKey, true);

    if (shouldEnable == true) {
      final enabled = await _notificationService
          .requestPermissionAndEnableCurrentDevice();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Notifications enabled successfully'
                : 'Notification permission not granted',
          ),
          backgroundColor: enabled ? AppTheme.success : AppTheme.error,
        ),
      );
    }
  }

  // Navigation callback for child screens
  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: Stack(
          children: [
            // Tab content
            IndexedStack(
              index: _currentIndex,
              children: [
                HomeTab(
                  user: widget.user,
                  onNavigateToGyms: () => _navigateToTab(1),
                ),
                const GymsScreen(),
                const ScheduleScreen(),
                SettingsScreen(user: widget.user),
              ],
            ),

            // Floating bottom navigation bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FloatingBottomNavBar(
                currentIndex: _currentIndex,
                onTap: _navigateToTab,
                items: const [
                  NavBarItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Home',
                  ),
                  NavBarItem(
                    icon: Icons.fitness_center_outlined,
                    activeIcon: Icons.fitness_center,
                    label: 'Gyms',
                  ),
                  NavBarItem(
                    icon: Icons.calendar_today_outlined,
                    activeIcon: Icons.calendar_today,
                    label: 'Schedule',
                  ),
                  NavBarItem(
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings,
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
