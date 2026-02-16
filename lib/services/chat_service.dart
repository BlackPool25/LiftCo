// lib/services/chat_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';
import 'supabase_service.dart';

class ChatService {
  final SupabaseClient _supabase;
  late final SupabaseService _api;

  ChatService(this._supabase) {
    _api = SupabaseService(_supabase);
  }

  Future<List<ChatMessage>> fetchLatestMessages({
    required String sessionId,
    int limit = 20,
  }) async {
    try {
      final rows = await _supabase
          .from('chat_messages')
          .select('id, session_id, user_id, content, type, created_at')
          .eq('session_id', sessionId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('fetchLatestMessages error: ${e.message}');
      throw Exception('Failed to load messages: ${e.message}');
    } catch (e) {
      debugPrint('fetchLatestMessages unexpected error: $e');
      throw Exception('Failed to load messages');
    }
  }

  Future<List<ChatMessage>> fetchOlderMessages({
    required String sessionId,
    required DateTime before,
    int limit = 20,
  }) async {
    try {
      final rows = await _supabase
          .from('chat_messages')
          .select('id, session_id, user_id, content, type, created_at')
          .eq('session_id', sessionId)
          .lt('created_at', before.toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(ChatMessage.fromJson)
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('fetchOlderMessages error: ${e.message}');
      throw Exception('Failed to load older messages: ${e.message}');
    } catch (e) {
      debugPrint('fetchOlderMessages unexpected error: $e');
      throw Exception('Failed to load older messages');
    }
  }

  Future<ChatMessage> sendTextMessage({
    required String sessionId,
    required String content,
  }) async {
    final response = await _api.post(
      'chat-send-message',
      body: {
        'session_id': sessionId,
        'content': content,
        'type': 'text',
      },
    );

    final messageJson = response['chat_message'] as Map<String, dynamic>?;
    if (messageJson == null) {
      throw Exception('Failed to send message');
    }
    return ChatMessage.fromJson(messageJson);
  }

  RealtimeChannel subscribeToNewMessages({
    required String sessionId,
    required void Function(ChatMessage message) onInsert,
  }) {
    final channel = _supabase.channel('chat:$sessionId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (payload) {
            try {
              onInsert(ChatMessage.fromJson(Map<String, dynamic>.from(payload.newRecord)));
            } catch (e) {
              debugPrint('chat realtime payload parse error: $e');
            }
          },
        )
        .subscribe();

    return channel;
  }
}
