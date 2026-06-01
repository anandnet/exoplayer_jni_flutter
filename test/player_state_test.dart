import 'package:flutter_test/flutter_test.dart';
import 'package:exoplayer_jni_flutter/src/player_state.dart';

void main() {
  group('ExoPlayerState', () {
    test('exoPlayerStateFromInt maps STATE_IDLE (1)', () {
      expect(exoPlayerStateFromInt(1), ExoPlayerState.idle);
    });

    test('exoPlayerStateFromInt maps STATE_BUFFERING (2)', () {
      expect(exoPlayerStateFromInt(2), ExoPlayerState.buffering);
    });

    test('exoPlayerStateFromInt maps STATE_READY (3)', () {
      expect(exoPlayerStateFromInt(3), ExoPlayerState.ready);
    });

    test('exoPlayerStateFromInt maps STATE_ENDED (4)', () {
      expect(exoPlayerStateFromInt(4), ExoPlayerState.ended);
    });

    test('exoPlayerStateFromInt returns idle for unknown value', () {
      expect(exoPlayerStateFromInt(99), ExoPlayerState.idle);
      expect(exoPlayerStateFromInt(0), ExoPlayerState.idle);
      expect(exoPlayerStateFromInt(-1), ExoPlayerState.idle);
    });
  });

  group('ExoPlaybackException', () {
    test('stores errorCode and message', () {
      const ex = ExoPlaybackException(errorCode: 404, message: 'Not found');
      expect(ex.errorCode, equals(404));
      expect(ex.message, equals('Not found'));
      expect(ex.type, isNull);
    });

    test('stores optional type', () {
      const ex = ExoPlaybackException(
        errorCode: 1,
        message: 'IO error',
        type: 'TYPE_SOURCE',
      );
      expect(ex.type, equals('TYPE_SOURCE'));
    });

    test('toString contains code, type and message', () {
      const ex = ExoPlaybackException(
        errorCode: 2,
        message: 'decode error',
        type: 'TYPE_RENDERER',
      );
      final s = ex.toString();
      expect(s, contains('2'));
      expect(s, contains('TYPE_RENDERER'));
      expect(s, contains('decode error'));
    });
  });

  group('PlayerPosition', () {
    test('stores position, buffered and duration', () {
      const pp = PlayerPosition(
        position: Duration(seconds: 10),
        buffered: Duration(seconds: 30),
        duration: Duration(seconds: 120),
      );
      expect(pp.position, equals(const Duration(seconds: 10)));
      expect(pp.buffered, equals(const Duration(seconds: 30)));
      expect(pp.duration, equals(const Duration(seconds: 120)));
    });

    test('zero values are valid', () {
      const pp = PlayerPosition(
        position: Duration.zero,
        buffered: Duration.zero,
        duration: Duration.zero,
      );
      expect(pp.position, equals(Duration.zero));
      expect(pp.duration, equals(Duration.zero));
    });

    test('progress ratio is computable', () {
      const pp = PlayerPosition(
        position: Duration(seconds: 60),
        buffered: Duration(seconds: 90),
        duration: Duration(seconds: 120),
      );
      final progress = pp.position.inMilliseconds / pp.duration.inMilliseconds;
      expect(progress, closeTo(0.5, 0.001));
    });
  });

  group('RepeatMode', () {
    test('enum has three values', () {
      expect(RepeatMode.values.length, equals(3));
    });

    test('values are off, one, all', () {
      expect(
          RepeatMode.values,
          containsAll([
            RepeatMode.off,
            RepeatMode.one,
            RepeatMode.all,
          ]));
    });
  });
}
