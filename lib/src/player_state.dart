/// Mirrors ExoPlayer's Player.STATE_* constants.
enum ExoPlayerState {
  /// ExoPlayer.STATE_IDLE = 1
  idle,

  /// ExoPlayer.STATE_BUFFERING = 2
  buffering,

  /// ExoPlayer.STATE_READY = 3
  ready,

  /// ExoPlayer.STATE_ENDED = 4
  ended,
}

ExoPlayerState exoPlayerStateFromInt(int state) {
  switch (state) {
    case 1:
      return ExoPlayerState.idle;
    case 2:
      return ExoPlayerState.buffering;
    case 3:
      return ExoPlayerState.ready;
    case 4:
      return ExoPlayerState.ended;
    default:
      return ExoPlayerState.idle;
  }
}

/// Playback exception information surfaced from ExoPlayer.
class ExoPlaybackException {
  final int errorCode;
  final String message;
  final String? type;

  const ExoPlaybackException({
    required this.errorCode,
    required this.message,
    this.type,
  });

  @override
  String toString() =>
      'ExoPlaybackException(code=$errorCode, type=$type, message=$message)';
}

/// Snapshot of the player's current position and duration.
class PlayerPosition {
  final Duration position;
  final Duration buffered;
  final Duration duration;

  const PlayerPosition({
    required this.position,
    required this.buffered,
    required this.duration,
  });
}

/// Repeat modes mirroring Player.REPEAT_MODE_*.
enum RepeatMode {
  /// Player.REPEAT_MODE_OFF = 0
  off,

  /// Player.REPEAT_MODE_ONE = 1
  one,

  /// Player.REPEAT_MODE_ALL = 2
  all,
}
