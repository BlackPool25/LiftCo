// lib/services/notification_service.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'current_user_resolver.dart';
import 'supabase_service.dart';

class NotificationService {
  final SupabaseClient _supabase;
  late final SupabaseService _api;

  NotificationService(this._supabase) {
    _api = SupabaseService(_supabase);
  }

  bool _isPermissionGranted(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
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
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      final isLocalhost = host == 'localhost' || host == '127.0.0.1';
      final isSecure = Uri.base.scheme.toLowerCase() == 'https';
      if (!isLocalhost && !isSecure) {
        throw Exception(
          'Web push requires HTTPS (or localhost). Open the app on a secure origin and retry.',
        );
      }
    }

    if (!kIsWeb && Platform.isAndroid) {
      final osPermission = await Permission.notification.status;
      if (!osPermission.isGranted) {
        final requested = await Permission.notification.request();
        if (!requested.isGranted) {
          throw Exception(
            'Notification permission is denied at Android system level.',
          );
        }
      }
    }

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (!_isPermissionGranted(settings.authorizationStatus)) {
      throw Exception('Firebase notification permission not granted.');
    }

    if (kIsWeb) {
      final current = await FirebaseMessaging.instance.getNotificationSettings();
      if (!_isPermissionGranted(current.authorizationStatus)) {
        throw Exception(
          'Browser notifications are blocked. Allow notifications for this site and retry.',
        );
      }
    }

    var token = await getFcmToken();
    if (token == null || token.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      token = await getFcmToken();
    }
    if (token == null || token.isEmpty) {
      throw Exception(
        'FCM token is unavailable. Check Firebase/Google Play Services setup.',
      );
    }

    final deviceInfo = await _getDeviceInfo();
    await enableNotifications(token, deviceInfo['type']!, deviceInfo['name']!);
    return true;
  }

  Future<String?> getFcmToken() async {
    try {
      if (kIsWeb) {
        final vapidKey = dotenv.env['FIREBASE_WEB_VAPID_KEY']?.trim() ?? '';
        if (vapidKey.isNotEmpty) {
          try {
            final token = await FirebaseMessaging.instance.getToken(
              vapidKey: vapidKey,
            );
            if (token != null && token.isNotEmpty) {
              return token;
            }
          } catch (vapidError) {
            debugPrint('FCM web token with VAPID failed: $vapidError');
          }
        } else {
          debugPrint(
            'Web push missing FIREBASE_WEB_VAPID_KEY, trying default web token flow.',
          );
        }

        return FirebaseMessaging.instance.getToken();
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
      if (!_isPermissionGranted(settings.authorizationStatus)) {
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

      // On web, the edge function path is frequently blocked by transient auth
      // gaps (401) during service worker/token setup. Direct DB upsert works
      // with our RLS policies and avoids extra edge-function requests.
      if (kIsWeb) {
        await _upsertDeviceDirectly(
          fcmToken: fcmToken,
          deviceType: deviceType,
          deviceName: deviceName,
        );

        final status = await getCurrentDeviceStatus();
        if (!(status['enabled'] as bool? ?? false)) {
          throw Exception(
            'Device registration was not persisted (authorized=${status['authorized']}, token=${status['token'] != null}, active_in_db=${status['active_in_db']})',
          );
        }
        return;
      }

      var edgeRegistered = false;
      try {
        await _api.registerDevice(
          fcmToken: fcmToken,
          deviceType: deviceType,
          deviceName: deviceName,
        );
        edgeRegistered = true;
      } catch (edgeError) {
        debugPrint('Edge register failed, falling back to direct DB write: $edgeError');
      }

      if (!edgeRegistered) {
        await _upsertDeviceDirectly(
          fcmToken: fcmToken,
          deviceType: deviceType,
          deviceName: deviceName,
        );
      }

      final status = await getCurrentDeviceStatus();
      if (!(status['enabled'] as bool? ?? false)) {
        throw Exception(
          'Device registration was not persisted (authorized=${status['authorized']}, token=${status['token'] != null}, active_in_db=${status['active_in_db']})',
        );
      }
    } on PostgrestException catch (e) {
      debugPrint('Error enabling notifications: ${e.message}');
      throw Exception('Failed to enable notifications: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error enabling notifications: $e');
      throw Exception('Failed to enable notifications: $e');
    }
  }

  Future<void> _upsertDeviceDirectly({
    required String fcmToken,
    required String deviceType,
    required String deviceName,
  }) async {
    final appUserId = await CurrentUserResolver.resolveAppUserId(_supabase);
    if (appUserId == null) {
      throw Exception('Unable to resolve app user id for direct device registration');
    }

    final now = DateTime.now().toIso8601String();
    final existing = await _supabase
        .from('user_devices')
        .select('id')
        .eq('user_id', appUserId)
        .eq('fcm_token', fcmToken)
        .maybeSingle();

    if (existing != null && existing['id'] != null) {
      await _supabase
          .from('user_devices')
          .update({
            'device_type': deviceType,
            'device_name': deviceName,
            'is_active': true,
            'last_seen_at': now,
            'updated_at': now,
          })
          .eq('id', existing['id']);
      return;
    }

    await _supabase.from('user_devices').insert({
      'user_id': appUserId,
      'fcm_token': fcmToken,
      'device_type': deviceType,
      'device_name': deviceName,
      'is_active': true,
      'last_seen_at': now,
      'created_at': now,
      'updated_at': now,
    });
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
        final isAuthorized = _isPermissionGranted(settings.authorizationStatus);

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
