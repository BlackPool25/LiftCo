// lib/services/device_service.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceService {
  final SupabaseClient _supabase;
  final FirebaseMessaging _messaging;
  final DeviceInfoPlugin _deviceInfo;

  DeviceService(this._supabase)
      : _messaging = FirebaseMessaging.instance,
        _deviceInfo = DeviceInfoPlugin();

  /// Register device with FCM token for push notifications
  Future<void> registerDevice(String userId) async {
    try {
      // Request notification permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Notification permission denied');
        return;
      }

      // Get FCM token
      final fcmToken = await _messaging.getToken();
      if (fcmToken == null) {
        debugPrint('Failed to get FCM token');
        return;
      }

      // Get device info
      final deviceInfo = await _getDeviceInfo();

      // Upsert device record (update if exists, insert if new)
      await _supabase.from('user_devices').upsert(
        {
          'user_id': userId,
          'fcm_token': fcmToken,
          'device_type': deviceInfo['type'],
          'device_name': deviceInfo['name'],
          'is_active': true,
          'last_seen_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id, fcm_token',
      );

      debugPrint('Device registered successfully with token: ${fcmToken.substring(0, 20)}...');

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        await _updateFcmToken(userId, fcmToken, newToken);
      });
    } catch (e) {
      debugPrint('Failed to register device: $e');
    }
  }

  /// Update FCM token when it refreshes
  Future<void> _updateFcmToken(String userId, String oldToken, String newToken) async {
    try {
      await _supabase
          .from('user_devices')
          .update({
            'fcm_token': newToken,
            'last_seen_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('fcm_token', oldToken);

      debugPrint('FCM token updated successfully');
    } catch (e) {
      debugPrint('Failed to update FCM token: $e');
    }
  }

  /// Get device information
  Future<Map<String, String>> _getDeviceInfo() async {
    String deviceType = 'unknown';
    String deviceName = 'Unknown Device';

    try {
      if (kIsWeb) {
        deviceType = 'web';
        final webInfo = await _deviceInfo.webBrowserInfo;
        deviceName = '${webInfo.browserName.name} on ${webInfo.platform ?? "Web"}';
      } else if (Platform.isAndroid) {
        deviceType = 'android';
        final androidInfo = await _deviceInfo.androidInfo;
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        deviceType = 'ios';
        final iosInfo = await _deviceInfo.iosInfo;
        deviceName = '${iosInfo.name} (${iosInfo.model})';
      }
    } catch (e) {
      debugPrint('Failed to get device info: $e');
    }

    return {
      'type': deviceType,
      'name': deviceName,
    };
  }

  /// Deactivate device (e.g., on logout)
  Future<void> deactivateDevice(String userId) async {
    try {
      final fcmToken = await _messaging.getToken();
      if (fcmToken == null) return;

      await _supabase
          .from('user_devices')
          .update({
            'is_active': false,
            'last_seen_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('fcm_token', fcmToken);

      debugPrint('Device deactivated successfully');
    } catch (e) {
      debugPrint('Failed to deactivate device: $e');
    }
  }

  /// Update last seen timestamp (call periodically)
  Future<void> updateLastSeen(String userId) async {
    try {
      final fcmToken = await _messaging.getToken();
      if (fcmToken == null) return;

      await _supabase
          .from('user_devices')
          .update({
            'last_seen_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('fcm_token', fcmToken);
    } catch (e) {
      debugPrint('Failed to update last seen: $e');
    }
  }
}
