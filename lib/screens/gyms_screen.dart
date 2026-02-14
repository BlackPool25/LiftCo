// lib/screens/gyms_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../models/gym.dart';
import '../services/gym_service.dart';
import '../widgets/glass_card.dart';
import 'gym_details_screen.dart';

/// Gyms screen - shows nearby gyms and available sessions
class GymsScreen extends StatefulWidget {
  const GymsScreen({super.key});

  @override
  State<GymsScreen> createState() => _GymsScreenState();
}

class _GymsScreenState extends State<GymsScreen> {
  late GymService _gymService;
  List<Gym> _gyms = [];
  List<Gym> _filteredGyms = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _gymService = GymService(Supabase.instance.client);
    _loadGyms();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGyms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final gyms = await _gymService.getGyms();
      setState(() {
        _gyms = gyms;
        _filteredGyms = gyms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterGyms(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredGyms = _gyms;
      } else {
        _filteredGyms = _gyms.where((gym) {
          final nameMatch = gym.name.toLowerCase().contains(
            query.toLowerCase(),
          );
          final addressMatch =
              gym.address?.toLowerCase().contains(query.toLowerCase()) ?? false;
          return nameMatch || addressMatch;
        }).toList();
      }
    });
  }

  void _navigateToGymDetails(Gym gym) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GymDetailsScreen(gym: gym)),
    );
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
                    'Explore Gyms',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ).animate().fadeIn().slideY(begin: -0.2),
                ),
                const SizedBox(width: 12),
                GlassCard(
                  onTap: _isLoading ? null : _loadGyms,
                  padding: const EdgeInsets.all(12),
                  borderRadius: 14,
                  child: _isLoading
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
            const SizedBox(height: 8),
            Text(
              'Find sessions at gyms near you',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),

            // Search bar
            GlassCard(
              padding: EdgeInsets.zero,
              borderRadius: 16,
              child: TextField(
                controller: _searchController,
                onChanged: _filterGyms,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search gyms...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppTheme.textMuted,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppTheme.textMuted,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _filterGyms('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

            const SizedBox(height: 24),

            // Gyms list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryPurple,
                      ),
                    )
                  : _error != null
                  ? _buildErrorState()
                  : _filteredGyms.isEmpty
                  ? _buildEmptyState()
                  : _buildGymsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
          const SizedBox(height: 16),
          Text(
            'Failed to load gyms',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadGyms, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
            _searchController.text.isEmpty
                ? 'No gyms found'
                : 'No matching gyms',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty
                ? 'Check back later for new gyms'
                : 'Try a different search term',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGymsList() {
    return RefreshIndicator(
      onRefresh: _loadGyms,
      color: AppTheme.primaryPurple,
      backgroundColor: AppTheme.surface,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: _filteredGyms.length,
        itemBuilder: (context, index) {
          final gym = _filteredGyms[index];
          return _buildGymCard(gym, index);
        },
      ),
    );
  }

  Widget _buildGymCard(Gym gym, int index) {
    return GlassCard(
      onTap: () => _navigateToGymDetails(gym),
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Row(
        children: [
          // Gym image placeholder
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryPurple.withValues(alpha: 0.3),
                  AppTheme.accentCyan.withValues(alpha: 0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(
                Icons.fitness_center,
                color: AppTheme.textSecondary,
                size: 32,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Gym info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gym.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  gym.formattedAddress,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: AppTheme.accentCyan,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      gym.formattedHours,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Arrow
          const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 24),
        ],
      ),
    ).animate().fadeIn(delay: (150 + index * 50).ms).slideY(begin: 0.1);
  }
}
