// lib/services/gym_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gym.dart';
import '../models/workout_session.dart';

class GymService {
  final SupabaseClient _supabase;

  GymService(this._supabase);

  /// Fetch all gyms with optional search
  Future<List<Gym>> getGyms({String? searchQuery}) async {
    try {
      final List<Map<String, dynamic>> data;

      if (searchQuery != null && searchQuery.isNotEmpty) {
        data = await _supabase
            .from('gyms')
            .select()
            .or('name.ilike.%$searchQuery%,address.ilike.%$searchQuery%')
            .order('name', ascending: true);
      } else {
        data = await _supabase
            .from('gyms')
            .select()
            .order('name', ascending: true);
      }

      return data.map((json) => Gym.fromJson(json)).toList();
    } on PostgrestException catch (e) {
      debugPrint('Error fetching gyms: ${e.message}');
      throw Exception('Failed to fetch gyms: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error fetching gyms: $e');
      throw Exception('Failed to fetch gyms');
    }
  }

  /// Get a single gym by ID
  Future<Gym?> getGymById(int id) async {
    try {
      final response = await _supabase
          .from('gyms')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Gym.fromJson(response);
    } on PostgrestException catch (e) {
      debugPrint('Error fetching gym: ${e.message}');
      throw Exception('Failed to fetch gym: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error fetching gym: $e');
      throw Exception('Failed to fetch gym');
    }
  }

  /// Get available sessions for a gym
  /// Returns sessions that are upcoming and not full
  Future<List<WorkoutSession>> getGymSessions(int gymId) async {
    try {
      // Fetch sessions without nested members (to avoid relationship issues)
      final response = await _supabase
          .from('workout_sessions')
          .select('''
            *,
            host:host_user_id(id, name)
          ''')
          .eq('gym_id', gymId)
          .eq('status', 'upcoming')
          .gte('start_time', DateTime.now().toIso8601String())
          .order('start_time', ascending: true);

      return response
          .map((json) => WorkoutSession.fromJson(json))
          .where((session) => !session.isFull)
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('Error fetching gym sessions: ${e.message}');
      throw Exception('Failed to fetch sessions: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error fetching gym sessions: $e');
      throw Exception('Failed to fetch sessions');
    }
  }

  /// Search gyms by name or address
  Future<List<Gym>> searchGyms(String query) async {
    if (query.isEmpty) return getGyms();

    try {
      final response = await _supabase
          .from('gyms')
          .select()
          .or('name.ilike.%$query%,address.ilike.%$query%')
          .order('name', ascending: true);

      return response.map((json) => Gym.fromJson(json)).toList();
    } on PostgrestException catch (e) {
      debugPrint('Error searching gyms: ${e.message}');
      throw Exception('Failed to search gyms: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error searching gyms: $e');
      throw Exception('Failed to search gyms');
    }
  }
}
