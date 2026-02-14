// lib/services/device_service.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:synchronized/synchronized.dart';
import 'current_user_resolver.dart';
import 'supabase_service.dart';

class DeviceService {
  final SupabaseClient _supabase;
  final FirebaseMessaging _messaging;
  final DeviceInfoPlugin _deviceInfo;
  late final SupabaseService _api;

  static final Lock _registerLock = Lock();
  static Future<void>? _inFlightRegister;
  StreamSubscription<String>? _tokenRefreshSubscription;

  static const Duration _registerTtl = Duration(hours: 24);

  DeviceService(this._supabase)
    : _messaging = FirebaseMessaging.instance,
      _deviceInfo = DeviceInfoPlugin() {
    _api = SupabaseService(_supabase);
  }

  Future<String?> _getFcmToken() async {
    try {
      if (kIsWeb) {
        final vapidKey = dotenv.env['FIREBASE_WEB_VAPID_KEY']?.trim() ?? '';
        if (vapidKey.isEmpty) {
          debugPrint('Missing FIREBASE_WEB_VAPID_KEY for web push token');
          return null;
        }
        return _messaging.getToken(vapidKey: vapidKey);
      }

      return _messaging.getToken();
    } catch (e) {
      debugPrint('FCM token fetch failed: $e');
      return null;
    }
  }

  String _prefsTokenKey(String userId) => 'device_reg_last_token_$userId';
  String _prefsRegisteredAtKey(String userId) => 'device_reg_last_at_$userId';

  /// Register device with FCM token for push notifications
  /// Uses the devices-register edge function (which has service role access)
  Future<void> registerDevice({required bool requestPermissionIfNeeded}) async {
    return _registerLock.synchronized(() {
      _inFlightRegister ??= _registerDeviceInternal(
        requestPermissionIfNeeded: requestPermissionIfNeeded,
      ).whenComplete(() {
        _inFlightRegister = null;
      });
      return _inFlightRegister!;
    });
  }

  Future<void> _registerDeviceInternal({
    required bool requestPermissionIfNeeded,
  }) async {
    try {
      final userId = await CurrentUserResolver.resolveAppUserId(_supabase);
      if (userId == null) {
        debugPrint('Failed to resolve app user ID for device registration');
        return;
      }

      // Avoid repeated permission prompts from background refresh/navigation.
      if (requestPermissionIfNeeded) {
        final settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          debugPrint('Notification permission denied');
          return;
        }
      } else {
        final settings = await _messaging.getNotificationSettings();
        final status = settings.authorizationStatus;
        final granted = status == AuthorizationStatus.authorized ||
            status == AuthorizationStatus.provisional;
        if (!granted) return;
      }

      // Get FCM token
      final fcmToken = await _getFcmToken();
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('Failed to get FCM token');
        return;
      }

      // Short-circuit if we recently registered the same token.
      final prefs = await SharedPreferences.getInstance();
      final lastToken = prefs.getString(_prefsTokenKey(userId));
      final lastAtRaw = prefs.getString(_prefsRegisteredAtKey(userId));
      final lastAt = lastAtRaw == null ? null : DateTime.tryParse(lastAtRaw);
      if (lastToken == fcmToken &&
          lastAt != null &&
          DateTime.now().difference(lastAt) < _registerTtl) {
        _ensureTokenRefreshListener();
        return;
      }

      // Get device info
      final deviceInfo = await _getDeviceInfo();

      if (kIsWeb) {
        await _supabase.from('user_devices').upsert({
          'user_id': userId,
          'fcm_token': fcmToken,
          'device_type': deviceInfo['type'],
          'device_name': deviceInfo['name'],
          'is_active': true,
          'last_seen_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id, fcm_token');
      } else {
        // Register via edge function (bypasses RLS via service role)
        try {
          await _api.registerDevice(
            fcmToken: fcmToken,
            deviceType: deviceInfo['type']!,
            deviceName: deviceInfo['name'],
          );
        } catch (edgeError) {
          debugPrint('Edge function register failed, trying direct DB: $edgeError');
          // Fallback to direct DB upsert (requires valid JWT + RLS policies).
          await _supabase.from('user_devices').upsert({
            'user_id': userId,
            'fcm_token': fcmToken,
            'device_type': deviceInfo['type'],
            'device_name': deviceInfo['name'],
            'is_active': true,
            'last_seen_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id, fcm_token');
        }
      }

      await prefs.setString(_prefsTokenKey(userId), fcmToken);
      await prefs.setString(
        _prefsRegisteredAtKey(userId),
        DateTime.now().toIso8601String(),
      );

      _ensureTokenRefreshListener();
    } catch (e) {
      debugPrint('Failed to register device: $e');
    }
  }

  void _ensureTokenRefreshListener() {
    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen((newToken) {
      _handleTokenRefreshFromPrefs(newToken);
    });
  }

  Future<void> _handleTokenRefreshFromPrefs(String newToken) async {
    try {
      final userId = await CurrentUserResolver.resolveAppUserId(_supabase);
      if (userId == null) return;

      final prefs = await SharedPreferences.getInstance();
      final oldToken = prefs.getString(_prefsTokenKey(userId));
      if (oldToken == newToken) return;

      await _handleTokenRefresh(userId, oldToken, newToken);
      await prefs.setString(_prefsTokenKey(userId), newToken);
      await prefs.setString(
        _prefsRegisteredAtKey(userId),
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Failed to process token refresh: $e');
    }
  }

  /// Handle FCM token refresh by registering the new token
  Future<void> _handleTokenRefresh(
    String userId,
    String? oldToken,
    String newToken,
  ) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      if (kIsWeb) {
        await _supabase.from('user_devices').upsert({
          'user_id': userId,
          'fcm_token': newToken,
          'device_type': deviceInfo['type'],
          'device_name': deviceInfo['name'],
          'is_active': true,
          'last_seen_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id, fcm_token');
      } else {
        // Register new token via edge function
        try {
          await _api.registerDevice(
            fcmToken: newToken,
            deviceType: deviceInfo['type']!,
            deviceName: deviceInfo['name'],
          );
        } catch (_) {
          // Fallback to direct DB
          await _supabase.from('user_devices').upsert({
            'user_id': userId,
            'fcm_token': newToken,
            'device_type': deviceInfo['type'],
            'device_name': deviceInfo['name'],
            'is_active': true,
            'last_seen_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id, fcm_token');
        }
      }

      // Deactivate old token
      if (oldToken != null && oldToken.isNotEmpty) {
        if (kIsWeb) {
          await _supabase
              .from('user_devices')
              .update({
                'is_active': false,
                'last_seen_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', userId)
              .eq('fcm_token', oldToken);
        } else {
          try {
            await _api.removeDevice(oldToken);
          } catch (_) {
            await _supabase
                .from('user_devices')
                .update({
                  'is_active': false,
                  'last_seen_at': DateTime.now().toIso8601String(),
                })
                .eq('user_id', userId)
                .eq('fcm_token', oldToken);
          }
        }
      }

      debugPrint('FCM token refreshed successfully');
    } catch (e) {
      debugPrint('Failed to handle FCM token refresh: $e');
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
        deviceName =
            '${webInfo.browserName.name} on ${webInfo.platform ?? "Web"}';
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

    return {'type': deviceType, 'name': deviceName};
  }

  /// Deactivate device (e.g., on logout)
  Future<void> deactivateDevice() async {
    try {
      final fcmToken = await _getFcmToken();
      if (fcmToken == null) return;

      // Use edge function to remove device
      try {
        await _api.removeDevice(fcmToken);
        debugPrint('Device deactivated via edge function');
      } catch (edgeError) {
        debugPrint('Edge function remove failed, trying direct DB: $edgeError');
        final userId = await CurrentUserResolver.resolveAppUserId(_supabase);
        if (userId == null) return;

        await _supabase
            .from('user_devices')
            .update({
              'is_active': false,
              'last_seen_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('fcm_token', fcmToken);
        debugPrint('Device deactivated via direct DB');
      }
    } catch (e) {
      debugPrint('Failed to deactivate device: $e');
    }
  }

  /// Update last seen timestamp (call periodically)
  Future<void> updateLastSeen() async {
    try {
      final userId = await CurrentUserResolver.resolveAppUserId(_supabase);
      if (userId == null) return;

      final fcmToken = await _getFcmToken();
      if (fcmToken == null) return;

      await _supabase
          .from('user_devices')
          .update({'last_seen_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId)
          .eq('fcm_token', fcmToken);
    } catch (e) {
      debugPrint('Failed to update last seen: $e');
    }
  }
}
