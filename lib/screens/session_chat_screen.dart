// lib/screens/session_chat_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/theme.dart';
import '../models/chat_message.dart';
import '../models/workout_session.dart';
import '../services/chat_service.dart';
import '../services/current_user_resolver.dart';
import '../services/session_service.dart';
import '../utils/chat_window.dart';
import '../widgets/glass_card.dart';

class SessionChatScreen extends StatefulWidget {
  final WorkoutSession session;

  const SessionChatScreen({super.key, required this.session});

  @override
  State<SessionChatScreen> createState() => _SessionChatScreenState();
}

class _SessionChatScreenState extends State<SessionChatScreen> {
  late final ChatService _chatService;
  late final SessionService _sessionService;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _composerController = TextEditingController();

  String? _currentUserId;
  WorkoutSession? _sessionDetails;
  Map<String, Map<String, dynamic>> _usersById = {};

  final List<ChatMessage> _messagesDesc = [];
  final Set<String> _messageIds = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  bool _isSending = false;
  RealtimeChannel? _channel;
  StreamSubscription<void>? _tick;
  ChatWindowInfo? _window;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(Supabase.instance.client);
    _sessionService = SessionService(Supabase.instance.client);
    _scrollController.addListener(_onScroll);
    _initialize();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _composerController.dispose();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final userId = await CurrentUserResolver.resolveAppUserId(
        Supabase.instance.client,
      );
      if (!mounted) return;
      setState(() {
        _currentUserId = userId;
      });

      final session = await _sessionService.getSession(
        widget.session.id,
        forceRefresh: true,
      );

      if (!mounted) return;
      setState(() {
        _sessionDetails = session ?? widget.session;
        _usersById = {
          for (final m in (_sessionDetails?.members ?? const <SessionMember>[]))
            if (m.user != null) m.userId: m.user!,
        };
      });

      await _loadInitialMessages();

      _window = ChatWindowInfo.fromSession(
        _sessionDetails ?? widget.session,
        DateTime.now(),
      );

      _tick?.cancel();
      _tick = Stream<void>.periodic(const Duration(seconds: 30))
          .listen((_) {
        if (!mounted) return;
        setState(() {
          _window = ChatWindowInfo.fromSession(
            _sessionDetails ?? widget.session,
            DateTime.now(),
          );
        });
      });

      if (_window?.isOpen == true) {
        _channel = _chatService.subscribeToNewMessages(
          sessionId: widget.session.id,
          onInsert: (message) {
            if (!mounted) return;
            if (_messageIds.contains(message.id)) return;
            setState(() {
              _messageIds.add(message.id);
              _messagesDesc.insert(0, message);
            });
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadInitialMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final latest = await _chatService.fetchLatestMessages(
      sessionId: widget.session.id,
      limit: 20,
    );

    if (!mounted) return;
    setState(() {
      _messagesDesc
        ..clear()
        ..addAll(latest);
      _messageIds
        ..clear()
        ..addAll(latest.map((m) => m.id));
      _hasMore = latest.length == 20;
    });
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 220) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    if (_messagesDesc.isEmpty) return;
    setState(() {
      _isLoadingMore = true;
    });
    try {
      final oldest = _messagesDesc.last;
      final older = await _chatService.fetchOlderMessages(
        sessionId: widget.session.id,
        before: oldest.createdAt,
        limit: 20,
      );

      if (!mounted) return;
      setState(() {
        for (final m in older) {
          if (_messageIds.add(m.id)) {
            _messagesDesc.add(m);
          }
        }
        _hasMore = older.length == 20;
      });
    } catch (e) {
      // Non-blocking. Keep existing messages.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _send() async {
    final window = _window ?? ChatWindowInfo.fromSession(widget.session, DateTime.now());
    if (!window.canSend) return;

    final text = _composerController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final sent = await _chatService.sendTextMessage(
        sessionId: widget.session.id,
        content: text,
      );

      if (!mounted) return;
      _composerController.clear();
      setState(() {
        if (_messageIds.add(sent.id)) {
          _messagesDesc.insert(0, sent);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _sessionDetails ?? widget.session;
    final window = _window ?? ChatWindowInfo.fromSession(session, DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${session.formattedDate} • ${session.formattedTime}',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: SafeArea(
          child: Column(
            children: [
              if (window.isLocked)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: GlassCard(
                    padding: const EdgeInsets.all(12),
                    borderRadius: 16,
                    child: Row(
                      children: [
                        const Icon(Icons.lock, color: AppTheme.textMuted, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Chat opens in ${formatDurationCompact(window.opensAt.difference(DateTime.now()))}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryPurple),
                      )
                    : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppTheme.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        itemCount: _messagesDesc.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_isLoadingMore && index == _messagesDesc.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            );
                          }

                          final message = _messagesDesc[index];
                          final isMine = message.userId != null && message.userId == _currentUserId;
                          return _buildBubble(session, message, isMine);
                        },
                      ),
              ),
              _buildComposer(window),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(ChatWindowInfo window) {
    if (!window.canSend) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Icon(
                window.isClosed ? Icons.lock_outline : Icons.schedule,
                color: AppTheme.textMuted,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  window.isClosed
                      ? 'Chat closed • read-only history'
                      : 'Chat opens in ${formatDurationCompact(window.opensAt.difference(DateTime.now()))}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                borderRadius: 18,
                child: TextField(
                  controller: _composerController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Type your message…',
                    hintStyle: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GlassCard(
              onTap: _isSending ? null : _send,
              padding: const EdgeInsets.all(14),
              borderRadius: 18,
              child: Icon(
                Icons.send_rounded,
                color: _isSending ? AppTheme.textMuted : AppTheme.primaryOrange,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(WorkoutSession session, ChatMessage message, bool isMine) {
    final created = message.createdAt.toLocal();
    final hh = created.hour.toString().padLeft(2, '0');
    final mm = created.minute.toString().padLeft(2, '0');
    final timeText = '$hh:$mm';

    final user = message.userId == null ? null : _usersById[message.userId!];
    final name = user?['name'] as String?;
    final photoUrl = user?['profile_photo_url'] as String?;

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMine ? null : AppTheme.surfaceLight,
        gradient: isMine ? AppTheme.primaryGradient : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMine ? 18 : 6),
          bottomRight: Radius.circular(isMine ? 6 : 18),
        ),
        border: isMine ? null : Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message.content,
            style: TextStyle(
              color: isMine ? Colors.white : AppTheme.textPrimary,
              fontSize: 14,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            timeText,
            style: TextStyle(
              color: isMine ? Colors.white.withValues(alpha: 0.75) : AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (isMine) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Align(alignment: Alignment.centerRight, child: bubble),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppTheme.surfaceLight,
            backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                ? NetworkImage(photoUrl)
                : null,
            child: (photoUrl == null || photoUrl.isEmpty)
                ? Text(
                    (name?.isNotEmpty == true)
                        ? name!.trimLeft().substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: bubble)),
        ],
      ),
    );
  }
}
