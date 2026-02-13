// lib/services/notification_service.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'current_user_resolver.dart';
import 'supabase_service.dart';

class NotificationService {
  final SupabaseClient _supabase;
  late final SupabaseService _api;

  NotificationService(this._supabase) {
    _api = SupabaseService(_supabase);
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceType = 'unknown';
    String deviceName = 'Unknown Device';

    try {
      if (kIsWeb) {
        deviceType = 'web';
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceName =
            '${webInfo.browserName.name} on ${webInfo.platform ?? "Web"}';
      } else if (Platform.isAndroid) {
        deviceType = 'android';
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        deviceType = 'ios';
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = '${iosInfo.name} (${iosInfo.model})';
      }
    } catch (e) {
      debugPrint('Failed to get device info: $e');
    }

    return {'type': deviceType, 'name': deviceName};
  }

  Future<bool> requestPermissionAndEnableCurrentDevice() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return false;
      }

      final token = await getFcmToken();
      if (token == null) return false;

      final deviceInfo = await _getDeviceInfo();
      await enableNotifications(token, deviceInfo['type']!, deviceInfo['name']!);
      return true;
    } catch (e) {
      debugPrint('Failed to enable current device notifications: $e');
      return false;
    }
  }

  Future<String?> getFcmToken() async {
    try {
      if (kIsWeb) {
        final vapidKey = dotenv.env['FIREBASE_WEB_VAPID_KEY']?.trim() ?? '';
        if (vapidKey.isEmpty) {
          debugPrint(
            'Web push is not configured. Missing FIREBASE_WEB_VAPID_KEY.',
          );
          return null;
        }
        return FirebaseMessaging.instance.getToken(vapidKey: vapidKey);
      }

      return FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('FCM token fetch failed: $e');
      return null;
    }
  }

  /// Check if notifications are enabled for current device
  /// Returns true only if:
  /// 1. Firebase messaging permission is authorized
  /// 2. Current device has an active FCM token in the database
  Future<bool> areNotificationsEnabled() async {
    try {
      final appUserId = await CurrentUserResolver.resolveAppUserId(_supabase);
      if (appUserId == null) return false;

      // Check Firebase messaging permission
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        return false;
      }

      // Get current FCM token
      final currentToken = await getFcmToken();
      if (currentToken == null) return false;

      // Check if this specific device token is active in database
      final response = await _supabase
          .from('user_devices')
          .select('is_active')
          .eq('user_id', appUserId)
          .eq('fcm_token', currentToken)
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
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        throw Exception('User not authenticated');
      }

      await _api.registerDevice(
        fcmToken: fcmToken,
        deviceType: deviceType,
        deviceName: deviceName,
      );

      final status = await getCurrentDeviceStatus();
      if (!(status['enabled'] as bool? ?? false)) {
        throw Exception('Device registration was not persisted');
      }
    } on PostgrestException catch (e) {
      debugPrint('Error enabling notifications: ${e.message}');
      throw Exception('Failed to enable notifications: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error enabling notifications: $e');
      throw Exception('Failed to enable notifications: $e');
    }
  }

  /// Disable notifications for current device
  Future<void> disableNotifications(String fcmToken) async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        throw Exception('User not authenticated');
      }

      await _api.removeDevice(fcmToken);
    } on PostgrestException catch (e) {
      debugPrint('Error disabling notifications: ${e.message}');
      throw Exception('Failed to disable notifications: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error disabling notifications: $e');
      throw Exception('Failed to disable notifications: $e');
    }
  }

  /// Get user's devices
  Future<List<Map<String, dynamic>>> getUserDevices() async {
    try {
      final appUserId = await CurrentUserResolver.resolveAppUserId(_supabase);
      if (appUserId == null) return [];

      final response = await _supabase
          .from('user_devices')
          .select()
          .eq('user_id', appUserId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching user devices: $e');
      return [];
    }
  }

  /// Get current device notification status
  Future<Map<String, dynamic>> getCurrentDeviceStatus() async {
    try {
      final appUserId = await CurrentUserResolver.resolveAppUserId(_supabase);
      if (appUserId == null) {
        return {'enabled': false, 'token': null};
      }

      // Check Firebase permission
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      final isAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized;

      // Get current token
      final token = await getFcmToken();

      if (!isAuthorized || token == null) {
        return {'enabled': false, 'token': token};
      }

      // Check database
      final response = await _supabase
          .from('user_devices')
          .select('is_active')
          .eq('user_id', appUserId)
          .eq('fcm_token', token)
          .maybeSingle();

      final isActive =
          response != null && (response['is_active'] as bool? ?? false);

      return {
        'enabled': isActive,
        'token': token,
        'authorized': isAuthorized,
        'active_in_db': isActive,
      };
    } catch (e) {
      debugPrint('Error getting current device status: $e');
      return {'enabled': false, 'token': null};
    }
  }
}
