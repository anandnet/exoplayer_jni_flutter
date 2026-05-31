import 'package:jni/jni.dart';

// ignore: uri_does_not_exist — generated at codegen time
import 'exoplayer.g.dart';
import 'drm_config.dart';

/// Fluent Dart builder that constructs a [MediaItem] JNI object.
///
/// The underlying [MediaItem.Builder] class (and its [MediaMetadata.Builder])
/// are called through the JNIgen-generated bindings in exoplayer.g.dart.
///
/// Example:
/// ```dart
/// final item = MediaItemBuilder()
///     .setUri('https://example.com/video.mp4')
///     .setMimeType('video/mp4')
///     .setTitle('My Video')
///     .setArtist('Some Artist')
///     .setDrmConfig(widevineConfig)
///     .build();
/// ```
class MediaItemBuilder {
  String? _uri;
  String? _mimeType;
  String? _mediaId;
  String? _title;
  String? _artist;
  String? _albumTitle;
  String? _artworkUri;
  DrmConfig? _drmConfig;
  final Map<String, String> _httpHeaders = {};
  Duration? _clipStart;
  Duration? _clipEnd;

  MediaItemBuilder setUri(String uri) {
    _uri = uri;
    return this;
  }

  MediaItemBuilder setMimeType(String mimeType) {
    _mimeType = mimeType;
    return this;
  }

  MediaItemBuilder setMediaId(String id) {
    _mediaId = id;
    return this;
  }

  MediaItemBuilder setTitle(String title) {
    _title = title;
    return this;
  }

  MediaItemBuilder setArtist(String artist) {
    _artist = artist;
    return this;
  }

  MediaItemBuilder setAlbumTitle(String album) {
    _albumTitle = album;
    return this;
  }

  MediaItemBuilder setArtworkUri(String uri) {
    _artworkUri = uri;
    return this;
  }

  MediaItemBuilder setDrmConfig(DrmConfig config) {
    _drmConfig = config;
    return this;
  }

  MediaItemBuilder addHttpHeader(String key, String value) {
    _httpHeaders[key] = value;
    return this;
  }

  /// Clip playback between [start] and [end].
  MediaItemBuilder setClipRange(Duration start, Duration end) {
    _clipStart = start;
    _clipEnd = end;
    return this;
  }

  /// Builds and returns the JNI [MediaItem] object.
  ///
  /// Must be called on the Android main thread (or a thread with a looper)
  /// because JNI calls into the Java layer.
  MediaItem build() {
    assert(_uri != null, 'URI must be set before calling build()');

    final itemBuilder = MediaItem$Builder();

    // Set URI
    itemBuilder.setUri(_uri!.toJString());

    // Set MIME type
    if (_mimeType != null) {
      itemBuilder.setMimeType(_mimeType!.toJString());
    }

    // Set media ID (defaults to URI if not set)
    if (_mediaId != null) {
      itemBuilder.setMediaId(_mediaId!.toJString());
    }

    // Build and attach MediaMetadata
    final metaBuilder = MediaMetadata$Builder();
    if (_title != null) metaBuilder.setTitle(_title!.toJString());
    if (_artist != null) metaBuilder.setArtist(_artist!.toJString());
    if (_albumTitle != null) metaBuilder.setAlbumTitle(_albumTitle!.toJString());
    if (_artworkUri != null) {
      metaBuilder.setArtworkUri(Uri.parse(_artworkUri!.toJString()));
    }
    itemBuilder.setMediaMetadata(metaBuilder.build());

    // DRM
    if (_drmConfig != null) {
      final drmScheme = switch (_drmConfig!.scheme.toLowerCase()) {
        'widevine' => 'edef8ba9-79d6-4ace-a3c8-27dcd51d21ed',
        'playready' => '9a04f079-9840-4286-ab92-e65be0885f95',
        'clearkey' => 'e2719d58-a985-b3c9-781a-b030af78d30e',
        _ => _drmConfig!.scheme,
      };
      final drmUuid = UUID.fromString(drmScheme.toJString());
      final drmBuilder = MediaItem$DrmConfiguration$Builder(drmUuid)
          .setLicenseUri$1(_drmConfig!.licenseUrl.toJString());

      if (_drmConfig!.licenseRequestHeaders.isNotEmpty) {
        final jMap = JHashMap<JString, JString>();
        _drmConfig!.licenseRequestHeaders.forEach((k, v) {
          jMap.put(k.toJString(), v.toJString());
        });
        drmBuilder?.setLicenseRequestHeaders(jMap);
      }

      if (_drmConfig!.multiSession) {
        drmBuilder?.setMultiSession(true);
      }

      itemBuilder.setDrmConfiguration(drmBuilder?.build());
    }

    // HTTP headers (for the data source, set via RequestMetadata)
    if (_httpHeaders.isNotEmpty) {
      final rmBuilder = MediaItem$RequestMetadata$Builder();
      final jMap = JHashMap<JString, JString>();
      _httpHeaders.forEach((k, v) {
        jMap.put(k.toJString(), v.toJString());
      });
      rmBuilder.setExtras(jMap);
      itemBuilder.setRequestMetadata(rmBuilder.build());
    }

    // Clip range
    if (_clipStart != null && _clipEnd != null) {
      itemBuilder.setClippingConfiguration(
        MediaItem$ClippingConfiguration$Builder()
            .setStartPositionMs(_clipStart!.inMilliseconds)
            ?.setEndPositionMs(_clipEnd!.inMilliseconds)
            ?.build(),
      );
    }

    return itemBuilder.build()!;
  }
}

/// Convenience: create a [MediaItem] from a plain URL string.
MediaItem simpleMediaItem(String url) =>
    MediaItemBuilder().setUri(url).build();
