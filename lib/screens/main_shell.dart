// lib/screens/main_shell.dart
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/user.dart' as app_user;
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
