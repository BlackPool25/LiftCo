// lib/services/supabase_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

/// Generic CRUD service using Supabase Edge Functions
/// Provides a standard interface for all database operations
class SupabaseService {
  final SupabaseClient _client;
  final String _baseUrl;

  SupabaseService(this._client)
    : _baseUrl = 'https://bpfptwqysbouppknzaqk.supabase.co';

  /// Get the authorization header for edge functions
  Map<String, String> get _headers {
    final session = _client.auth.currentSession;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${session?.accessToken ?? ''}',
    };
  }

  /// Generic GET request to edge function
  Future<Map<String, dynamic>> get(
    String functionName, {
    Map<String, dynamic>? params,
  }) async {
    try {
      final uri = params != null
          ? Uri.parse('$_baseUrl/functions/v1/$functionName').replace(
              queryParameters: params.map(
                (key, value) => MapEntry(key, value.toString()),
              ),
            )
          : Uri.parse('$_baseUrl/functions/v1/$functionName');

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Request failed');
      }
    } catch (e) {
      debugPrint('Error in GET $functionName: $e');
      rethrow;
    }
  }

  /// Generic POST request to edge function
  Future<Map<String, dynamic>> post(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/functions/v1/$functionName'),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Request failed');
      }
    } catch (e) {
      debugPrint('Error in POST $functionName: $e');
      rethrow;
    }
  }

  /// Generic PATCH/PUT request to edge function
  Future<Map<String, dynamic>> patch(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/functions/v1/$functionName'),
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Request failed');
      }
    } catch (e) {
      debugPrint('Error in PATCH $functionName: $e');
      rethrow;
    }
  }

  /// Generic DELETE request to edge function
  Future<Map<String, dynamic>> delete(
    String functionName, {
    Map<String, dynamic>? params,
  }) async {
    try {
      final uri = params != null
          ? Uri.parse('$_baseUrl/functions/v1/$functionName').replace(
              queryParameters: params.map(
                (key, value) => MapEntry(key, value.toString()),
              ),
            )
          : Uri.parse('$_baseUrl/functions/v1/$functionName');

      final response = await http.delete(uri, headers: _headers);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Request failed');
      }
    } catch (e) {
      debugPrint('Error in DELETE $functionName: $e');
      rethrow;
    }
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

    return get('sessions-list', params: params);
  }

  /// Get a single session by ID
  Future<Map<String, dynamic>> getSession(String sessionId) async {
    return get('sessions-get', params: {'id': sessionId});
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
    return get('gyms-get', params: {'id': gymId.toString()});
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
