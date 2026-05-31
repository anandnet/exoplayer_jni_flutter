## 0.1.0

* Initial release.
* Full ExoPlayer (Media3) API via JNIgen — no MethodChannel.
* Supports HLS, DASH, SmoothStreaming, and progressive media.
* Widevine, PlayReady, and ClearKey DRM.
* Local media caching via SimpleCache + LeastRecentlyUsedCacheEvictor.
* DefaultTrackSelector with Dart-fluent TrackSelectorHelper.
* Playlist management: set, add, remove, seek to item.
* Playback speed, volume, repeat mode, shuffle mode.
* State, position, and error streams.
* Raw JNI ExoPlayer access via `player.rawPlayer`.
* Modern jnigen Dart-script config in `tool/jnigen.dart` (no jnigen.yaml).
