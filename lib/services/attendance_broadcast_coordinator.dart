import 'dart:async';

import 'package:flutter/foundation.dart';

@immutable
class AttendanceBroadcastState {
  const AttendanceBroadcastState._({
    required this.isBroadcasting,
    required this.sessionId,
    required this.endsAt,
    required this.secondsRemaining,
  });

  const AttendanceBroadcastState.idle()
      : this._(
          isBroadcasting: false,
          sessionId: null,
          endsAt: null,
          secondsRemaining: 0,
        );

  const AttendanceBroadcastState.active({
    required String sessionId,
    required DateTime endsAt,
    required int secondsRemaining,
  }) : this._(
          isBroadcasting: true,
          sessionId: sessionId,
          endsAt: endsAt,
          secondsRemaining: secondsRemaining,
        );

  final bool isBroadcasting;
  final String? sessionId;
  final DateTime? endsAt;
  final int secondsRemaining;

  AttendanceBroadcastState copyWith({
    bool? isBroadcasting,
    String? sessionId,
    DateTime? endsAt,
    int? secondsRemaining,
  }) {
    return AttendanceBroadcastState._(
      isBroadcasting: isBroadcasting ?? this.isBroadcasting,
      sessionId: sessionId ?? this.sessionId,
      endsAt: endsAt ?? this.endsAt,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
    );
  }
}

class AttendanceBroadcastCoordinator {
  AttendanceBroadcastCoordinator._();

  static final AttendanceBroadcastCoordinator instance =
      AttendanceBroadcastCoordinator._();

  final ValueNotifier<AttendanceBroadcastState> notifier =
      ValueNotifier<AttendanceBroadcastState>(const AttendanceBroadcastState.idle());

  Timer? _ticker;

  void start({required String sessionId, required Duration duration}) {
    final now = DateTime.now();
    final endsAt = now.add(duration);
    final secondsRemaining = duration.inSeconds;

    notifier.value = AttendanceBroadcastState.active(
      sessionId: sessionId,
      endsAt: endsAt,
      secondsRemaining: secondsRemaining,
    );

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = notifier.value;
      if (!current.isBroadcasting || current.endsAt == null) return;

      final remaining = current.endsAt!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        stop(sessionId: current.sessionId);
        return;
      }

      notifier.value = current.copyWith(secondsRemaining: remaining);
    });
  }

  void stop({String? sessionId}) {
    final current = notifier.value;
    if (!current.isBroadcasting) return;
    if (sessionId != null && current.sessionId != sessionId) return;

    _ticker?.cancel();
    _ticker = null;
    notifier.value = const AttendanceBroadcastState.idle();
  }
}
