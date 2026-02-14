// lib/services/supabase_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:synchronized/synchronized.dart';

/// Generic CRUD service using Supabase Edge Functions
/// Provides a standard interface for all database operations
class SupabaseService {
  final SupabaseClient _client;

  // Global (static) lock/future so *all* SupabaseService instances share a
  // single in-flight refresh and avoid refresh storms (429 rate limits).
  static final Lock _refreshSessionLock = Lock();
  static Future<Session?>? _globalRefreshSessionFuture;

  SupabaseService(this._client);

  Future<Session?> _refreshSessionLocked() async {
    return _refreshSessionLock.synchronized(() {
      _globalRefreshSessionFuture ??= _client.auth
          .refreshSession()
          .then((response) => response.session)
          .catchError((e, _) {
            debugPrint('refreshSession failed: $e');
            return null;
          })
          .whenComplete(() {
            _globalRefreshSessionFuture = null;
          });

      return _globalRefreshSessionFuture!;
    });
  }

  String _encodeParams(Map<String, dynamic> params) {
    return params.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value.toString())}',
        )
        .join('&');
  }

  Future<Map<String, dynamic>> _invoke(
    String functionName, {
    HttpMethod method = HttpMethod.post,
    dynamic body,
    bool retryOnUnauthorized = true,
    bool retryOnRateLimit = true,
  }) async {
    try {
      Session? session = _client.auth.currentSession;
      session ??= await _refreshSessionLocked();

      final accessToken = session?.accessToken;
      final anonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim();
      final headers = <String, String>{};
      if (anonKey != null && anonKey.isNotEmpty) {
        headers['apikey'] = anonKey;
      }
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      final baseUrl = dotenv.env['SUPABASE_URL']?.trim();
      if (baseUrl == null || baseUrl.isEmpty) {
        throw Exception('SUPABASE_URL is not configured');
      }

      final uri = Uri.parse('$baseUrl/functions/v1/$functionName');
      final requestHeaders = <String, String>{...headers};
      if (body != null) {
        requestHeaders['Content-Type'] = 'application/json';
      }

      http.Response response;
      final encodedBody = body == null ? null : jsonEncode(body);
      switch (method) {
        case HttpMethod.get:
          response = await http.get(uri, headers: requestHeaders);
          break;
        case HttpMethod.post:
          response = await http.post(
            uri,
            headers: requestHeaders,
            body: encodedBody,
          );
          break;
        case HttpMethod.put:
          response = await http.put(
            uri,
            headers: requestHeaders,
            body: encodedBody,
          );
          break;
        case HttpMethod.patch:
          response = await http.patch(
            uri,
            headers: requestHeaders,
            body: encodedBody,
          );
          break;
        case HttpMethod.delete:
          response = await http.delete(
            uri,
            headers: requestHeaders,
            body: encodedBody,
          );
          break;
      }

      dynamic decodedData;
      if (response.body.isNotEmpty) {
        try {
          decodedData = jsonDecode(response.body);
        } catch (_) {
          decodedData = response.body;
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 429 && retryOnRateLimit) {
          // Back off briefly and retry once to avoid cascading failures during
          // rapid navigation / refresh storms.
          await Future.delayed(const Duration(milliseconds: 800));
          return _invoke(
            functionName,
            method: method,
            body: body,
            retryOnUnauthorized: retryOnUnauthorized,
            retryOnRateLimit: false,
          );
        }

        if (response.statusCode == 401 && retryOnUnauthorized) {
          final refreshedSession = await _refreshSessionLocked();
          if (refreshedSession != null) {
            return _invoke(
              functionName,
              method: method,
              body: body,
              retryOnUnauthorized: false,
              retryOnRateLimit: retryOnRateLimit,
            );
          }
        }

        final data = decodedData;
        if (data is Map<String, dynamic>) {
          final base = data['error']?.toString() ?? 'Request failed';
          final details = data['details']?.toString();
          final message = (details != null && details.isNotEmpty)
              ? '$base ($details)'
              : base;
          throw Exception(message);
        }
        throw Exception('Request failed');
      }

      final data = decodedData;
      if (data == null) return <String, dynamic>{};
      if (data is Map<String, dynamic>) return data;
      if (data is List) return {'data': data};
      return {'data': data};
    } catch (e) {
      debugPrint('Error invoking $functionName: $e');
      rethrow;
    }
  }

  /// Generic GET request to edge function
  Future<Map<String, dynamic>> get(
    String functionName, {
    Map<String, dynamic>? params,
  }) async {
    final target =
        params == null || params.isEmpty
        ? functionName
        : '$functionName?${_encodeParams(params)}';
    return _invoke(target, method: HttpMethod.get);
  }

  /// Generic POST request to edge function
  Future<Map<String, dynamic>> post(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    return _invoke(functionName, method: HttpMethod.post, body: body);
  }

  /// Generic PATCH/PUT request to edge function
  Future<Map<String, dynamic>> patch(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    return _invoke(functionName, method: HttpMethod.patch, body: body);
  }

  /// Generic DELETE request to edge function
  Future<Map<String, dynamic>> delete(
    String functionName, {
    Map<String, dynamic>? params,
  }) async {
    final target =
        params == null || params.isEmpty
        ? functionName
        : '$functionName?${_encodeParams(params)}';
    return _invoke(target, method: HttpMethod.delete);
  }

  // ==================== SESSIONS CRUD ====================

  /// List sessions with optional filters
  Future<Map<String, dynamic>> listSessions({
    int? gymId,
    String? status,
    String? sessionType,
    String? dateFrom,
    String? dateTo,
    int limit = 50,
    int offset = 0,
    bool joinedOnly = false,
  }) async {
    final params = <String, dynamic>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (gymId != null) params['gym_id'] = gymId.toString();
    if (status != null) params['status'] = status;
    if (sessionType != null) params['session_type'] = sessionType;
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    if (joinedOnly) params['joined_only'] = 'true';

    return get('sessions-list', params: params);
  }

  /// Get a single session by ID
  Future<Map<String, dynamic>> getSession(String sessionId) async {
    return get('sessions-get/$sessionId');
  }

  /// Create a new session
  Future<Map<String, dynamic>> createSession({
    required int gymId,
    required String title,
    required String sessionType,
    String? description,
    required DateTime startTime,
    required int durationMinutes,
    int maxCapacity = 4,
    String? intensityLevel,
    bool womenOnly = false,
  }) async {
    return post(
      'sessions-create',
      body: {
        'gym_id': gymId,
        'title': title,
        'session_type': sessionType,
        'description': description,
        'start_time': startTime.toIso8601String(),
        'duration_minutes': durationMinutes,
        'max_capacity': maxCapacity,
        'intensity_level': intensityLevel,
        'women_only': womenOnly,
      },
    );
  }

  /// Delete/Cancel a session
  Future<Map<String, dynamic>> deleteSession(String sessionId) async {
    return delete('sessions-delete', params: {'id': sessionId});
  }

  /// Join a session
  Future<Map<String, dynamic>> joinSession(String sessionId) async {
    return post('sessions-join', body: {'session_id': sessionId});
  }

  /// Leave a session
  Future<Map<String, dynamic>> leaveSession(String sessionId) async {
    return post('sessions-leave', body: {'session_id': sessionId});
  }

  // ==================== GYMS CRUD ====================

  /// List all gyms
  Future<Map<String, dynamic>> listGyms({String? search}) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }
    return get('gyms-list', params: params.isNotEmpty ? params : null);
  }

  /// Get a single gym by ID
  Future<Map<String, dynamic>> getGym(int gymId) async {
    return get('gyms-get/$gymId');
  }

  // ==================== USERS CRUD ====================

  /// Get current user profile
  Future<Map<String, dynamic>> getCurrentUser() async {
    return get('users-get-me');
  }

  /// Update current user profile
  Future<Map<String, dynamic>> updateCurrentUser(
    Map<String, dynamic> updates,
  ) async {
    return patch('users-update-me', body: updates);
  }

  // ==================== DEVICES CRUD ====================

  /// Register a device for push notifications
  Future<Map<String, dynamic>> registerDevice({
    required String fcmToken,
    required String deviceType,
    String? deviceName,
  }) async {
    return post(
      'devices-register',
      body: {
        'fcm_token': fcmToken,
        'device_type': deviceType,
        'device_name': deviceName,
      },
    );
  }

  /// Remove a device
  Future<Map<String, dynamic>> removeDevice(String fcmToken) async {
    return post('devices-remove', body: {'fcm_token': fcmToken});
  }

  // ==================== NOTIFICATIONS ====================

  /// Send a notification (admin/host only)
  Future<Map<String, dynamic>> sendNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    return post(
      'notifications-send',
      body: {'user_id': userId, 'title': title, 'body': body, 'data': data},
    );
  }
}
