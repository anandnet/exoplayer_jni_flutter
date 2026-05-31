import 'package:jni/jni.dart';
// ignore: uri_does_not_exist
import 'exoplayer.g.dart';

/// Helper to configure [DefaultTrackSelector.Parameters] from Dart.
///
/// Example:
/// ```dart
/// final params = TrackSelectorHelper()
///     .setPreferredAudioLanguage('en')
///     .setPreferredTextLanguage('en')
///     .setMaxVideoSizeSd()
///     .build(trackSelector);
/// ```
class TrackSelectorHelper {
  String? _audioLanguage;
  String? _textLanguage;
  bool _forceLowBitrate = false;
  bool _maxVideoSizeSd = false;
  bool _disableVideo = false;
  bool _disableAudio = false;
  bool _disableText = false;
  int? _maxVideoBitrate;
  int? _maxAudioBitrate;

  TrackSelectorHelper setPreferredAudioLanguage(String lang) {
    _audioLanguage = lang;
    return this;
  }

  TrackSelectorHelper setPreferredTextLanguage(String lang) {
    _textLanguage = lang;
    return this;
  }

  TrackSelectorHelper setForceLowBitrate(bool force) {
    _forceLowBitrate = force;
    return this;
  }

  /// Restrict video to SD (≤ 480p) — useful for bandwidth saving.
  TrackSelectorHelper setMaxVideoSizeSd() {
    _maxVideoSizeSd = true;
    return this;
  }

  TrackSelectorHelper setDisableVideo(bool disable) {
    _disableVideo = disable;
    return this;
  }

  TrackSelectorHelper setDisableAudio(bool disable) {
    _disableAudio = disable;
    return this;
  }

  TrackSelectorHelper setDisableText(bool disable) {
    _disableText = disable;
    return this;
  }

  TrackSelectorHelper setMaxVideoBitrate(int bitrate) {
    _maxVideoBitrate = bitrate;
    return this;
  }

  TrackSelectorHelper setMaxAudioBitrate(int bitrate) {
    _maxAudioBitrate = bitrate;
    return this;
  }

  /// Applies parameters to the given [DefaultTrackSelector].
  void apply(DefaultTrackSelector selector) {
    final builder = selector.buildUponParameters();

    if (_audioLanguage != null) {
      builder?.setPreferredAudioLanguage$1(_audioLanguage!.toJString());
    }
    if (_textLanguage != null) {
      builder?.setPreferredTextLanguage$1(_textLanguage!.toJString());
    }
    if (_forceLowBitrate) {
      builder?.setForceLowestBitrate$1(true);
    }
    if (_maxVideoSizeSd) {
      builder?.setMaxVideoSizeSd$1();
    }
    if (_disableVideo) {
      builder?.setTrackTypeDisabled$1(2 /* C.TRACK_TYPE_VIDEO */, true);
    }
    if (_disableAudio) {
      builder?.setTrackTypeDisabled$1(1 /* C.TRACK_TYPE_AUDIO */, true);
    }
    if (_disableText) {
      builder?.setTrackTypeDisabled$1(3 /* C.TRACK_TYPE_TEXT */, true);
    }
    if (_maxVideoBitrate != null) {
      builder?.setMaxVideoBitrate$1(_maxVideoBitrate!);
    }
    if (_maxAudioBitrate != null) {
      builder?.setMaxAudioBitrate$1(_maxAudioBitrate!);
    }

    selector.parameters$3 = builder;
  }
}
