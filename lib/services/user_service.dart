// lib/services/user_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final SupabaseClient _supabase;

  UserService(this._supabase);

  /// Update user's preferred time
  Future<void> updatePreferredTime(String preferredTime) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _supabase
          .from('users')
          .update({'preferred_time': preferredTime})
          .eq('id', user.id);
    } on PostgrestException catch (e) {
      debugPrint('Error updating preferred time: ${e.message}');
      throw Exception('Failed to update preferred time: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error updating preferred time: $e');
      throw Exception('Failed to update preferred time');
    }
  }

  /// Get current user profile
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }
}
