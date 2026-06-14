## 0.2.0

* **Feature:** Automatic audio focus handling (ducks audio on notifications, pauses on calls). Added `handleAudioFocus` param to `init()`.
* **Feature:** Support custom cache keys for media items (`setCustomCacheKey`) and playlists (`cacheKeys` in `setPlaylistUrls`).
* **Feature:** Query cache status via `isCached(urlOrKey)` and `getCachedBytes(urlOrKey)`.
* **Fix:** Crash when playing local files via the `file://` scheme.
* **Fix:** R8/ProGuard crash in release builds (added `consumer-rules.pro` to keep JNI-reflected Media3 classes).

## 0.1.0* Initial release.
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
