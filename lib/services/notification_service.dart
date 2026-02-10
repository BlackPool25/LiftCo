// lib/services/notification_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final SupabaseClient _supabase;

  NotificationService(this._supabase);

  /// Check if notifications are enabled for current device
  Future<bool> areNotificationsEnabled() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final response = await _supabase
          .from('user_devices')
          .select('is_active')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return false;
      return response['is_active'] as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking notification status: $e');
      return false;
    }
  }

  /// Enable notifications for current device
  Future<void> enableNotifications(
    String fcmToken,
    String deviceType,
    String deviceName,
  ) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if device exists
      final existingDevice = await _supabase
          .from('user_devices')
          .select('id')
          .eq('user_id', user.id)
          .eq('fcm_token', fcmToken)
          .maybeSingle();

      if (existingDevice != null) {
        // Reactivate existing device
        await _supabase
            .from('user_devices')
            .update({
              'is_active': true,
              'last_seen_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existingDevice['id']);
      } else {
        // Register new device
        await _supabase.from('user_devices').insert({
          'user_id': user.id,
          'fcm_token': fcmToken,
          'device_type': deviceType,
          'device_name': deviceName,
          'is_active': true,
          'last_seen_at': DateTime.now().toIso8601String(),
        });
      }
    } on PostgrestException catch (e) {
      debugPrint('Error enabling notifications: ${e.message}');
      throw Exception('Failed to enable notifications: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error enabling notifications: $e');
      throw Exception('Failed to enable notifications');
    }
  }

  /// Disable notifications for current device
  Future<void> disableNotifications(String fcmToken) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _supabase
          .from('user_devices')
          .update({
            'is_active': false,
            'last_seen_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', user.id)
          .eq('fcm_token', fcmToken);
    } on PostgrestException catch (e) {
      debugPrint('Error disabling notifications: ${e.message}');
      throw Exception('Failed to disable notifications: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error disabling notifications: $e');
      throw Exception('Failed to disable notifications');
    }
  }

  /// Get user's devices
  Future<List<Map<String, dynamic>>> getUserDevices() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('user_devices')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching user devices: $e');
      return [];
    }
  }
}
