// lib/utils/chat_window.dart
import '../models/workout_session.dart';

enum ChatWindowState { locked, open, closed }

class ChatWindowInfo {
  final ChatWindowState state;
  final DateTime opensAt;
  final DateTime closesAt;

  const ChatWindowInfo({
    required this.state,
    required this.opensAt,
    required this.closesAt,
  });

  bool get isOpen => state == ChatWindowState.open;
  bool get isLocked => state == ChatWindowState.locked;
  bool get isClosed => state == ChatWindowState.closed;

  /// Writable only during the open window.
  bool get canSend => isOpen;

  static ChatWindowInfo fromSession(WorkoutSession session, DateTime now) {
    final opensAt = session.startTime.subtract(const Duration(days: 1));
    final closesAt = session.endTime.add(const Duration(hours: 2));

    final state = now.isBefore(opensAt)
        ? ChatWindowState.locked
        : (now.isAfter(closesAt) ? ChatWindowState.closed : ChatWindowState.open);

    return ChatWindowInfo(state: state, opensAt: opensAt, closesAt: closesAt);
  }
}

String formatDurationCompact(Duration duration) {
  var seconds = duration.inSeconds;
  if (seconds < 0) seconds = 0;

  final days = seconds ~/ 86400;
  seconds %= 86400;
  final hours = seconds ~/ 3600;
  seconds %= 3600;
  final minutes = seconds ~/ 60;

  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}
