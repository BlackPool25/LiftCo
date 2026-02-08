// lib/screens/gyms_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';
import '../widgets/glass_card.dart';

/// Gyms screen - shows nearby gyms and available sessions
class GymsScreen extends StatelessWidget {
  const GymsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Explore Gyms',
              style: Theme.of(context).textTheme.headlineLarge,
            ).animate().fadeIn().slideY(begin: -0.2),
            const SizedBox(height: 8),
            Text(
              'Find sessions at gyms near you',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            
            // Search bar
            GlassCard(
              padding: EdgeInsets.zero,
              borderRadius: 16,
              child: TextField(
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search gyms...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  filled: true,
                ),
              ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
            
            const SizedBox(height: 24),
            
            // Empty state
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: AppTheme.textMuted,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Discover Gyms',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Set your location to find\nnearby workout sessions',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ).animate().fadeIn(delay: 200.ms),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
