# exoplayer_jni_flutter

A Flutter plugin that exposes the **full Media3 ExoPlayer API** from Dart via **JNIgen-generated bindings** — no MethodChannel, no serialization overhead, just direct JNI calls.

Works for both **video** and **audio-only** playback with a single unified API.

---

## Table of contents

1. [Architecture](#architecture)
2. [Setup](#setup)
3. [Quick start — video player](#quick-start--video-player)
4. [Quick start — audio-only player](#quick-start--audio-only-player)
5. [ExoPlayerWidget](#exoplayerwidget)
6. [ExoPlayerController](#exoplayercontroller)
   - [Lifecycle](#lifecycle)
   - [Playback controls](#playback-controls)
   - [Volume & speed](#volume--speed)
   - [Playlists](#playlists)
   - [Repeat & shuffle](#repeat--shuffle)
   - [Streams — state, position, errors](#streams)
   - [Reading observable state](#reading-observable-state)
7. [MediaItem builder](#mediaitem-builder)
8. [DRM-protected content](#drm-protected-content)
9. [Track selection](#track-selection)
10. [Caching](#caching)
    - [Auto pre-caching for playlists](#auto-pre-caching-for-playlists)
11. [Buffer tuning](#buffer-tuning)
12. [Error handling](#error-handling)
13. [Raw JNI access](#raw-jni-access)
14. [Project structure](#project-structure)
15. [Requirements](#requirements)
16. [Troubleshooting](#troubleshooting)

---

## Architecture

### What you actually touch

Most apps only need two classes:

| Class | What it does | When to use it |
|---|---|---|
| `ExoPlayerWidget` | Drop-in widget — owns its own controller, handles surface lifecycle | Video playback, quick integration |
| `ExoPlayerController` | Headless controller you manage yourself | Audio-only, custom UI, multiple players |

A typical app never goes deeper than that:

```
Your Widget tree
  └─► ExoPlayerWidget          ← renders video + manages surface
        └─► ExoPlayerController  ← play / pause / seek / playlist / DRM / speed
              └─► MediaItemBuilder  ← build a media item (URL, metadata, DRM)
```

For audio-only you skip the widget entirely:

```
Your Widget tree
  └─► ExoPlayerController   ← create in initState(), dispose() in dispose()
        └─► MediaItemBuilder
```

### Power-user escape hatch

If you need something `ExoPlayerController` doesn't expose, every generated
ExoPlayer Java class is available directly from `lib/src/exoplayer.g.dart`:

```
ExoPlayerController.player   ← the raw JNI ExoPlayer instance
  └─► Full androidx.media3 API, zero wrapping
```

### How it works under the hood

```
ExoPlayerController
  └─► exoplayer.g.dart       (JNIgen-generated Dart bindings — do not edit)
        └─► dart:ffi + JNI
              └─► androidx.media3.*  (runs in the Android JVM)
```

No MethodChannel, no serialization — every Dart call is a direct JNI call.

| | exoplayer_jni_flutter | MethodChannel players |
|---|---|---|
| Serialization | None — Dart holds JNI references | JSON per call |
| API coverage | Full ExoPlayer API | Only what the plugin author wrapped |
| Type safety | JNIgen generates typed Dart classes | Dynamic maps |
| Overhead | Near-zero | ~0.1–0.5 ms per call |

---

## Setup

### 1. Add dependencies

```yaml
dependencies:
  exoplayer_jni_flutter:
    git:
      url: https://github.com/anandnet/exoplayer_jni_flutter.git
      ref: main
```

### 2. Android permissions

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Required for network streams -->
<uses-permission android:name="android.permission.INTERNET"/>

<!-- Required only for background/foreground-service playback -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
```

---

## Quick start — video player

### Option A: Drop-in widget (simplest)

```dart
import 'package:exoplayer_jni_flutter/exoplayer_jni_flutter.dart';

// Paste this anywhere in your widget tree.
// The widget creates and owns its own controller internally.
ExoPlayerWidget(
  initialUrl: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  autoPlay: true,
)
```

The widget handles `init()`, `attachTexture()`, `dispose()`, fullscreen rotation,
lifecycle resume, and error display automatically.

### Option B: External controller (full control)

```dart
class VideoScreen extends StatefulWidget { ... }

class _VideoScreenState extends State<VideoScreen> {
  late final ExoPlayerController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = ExoPlayerController();
    _init();
  }

  Future<void> _init() async {
    await _ctrl.init(
      cacheConfig: const CacheConfig(maxBytes: 200 * 1024 * 1024), // 200 MB
    );
    _ctrl.setMediaUrl('https://example.com/video.m3u8');
    _ctrl.play();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose(); // always dispose to release JNI/ExoPlayer resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ExoPlayerWidget(controller: _ctrl), // widget just renders the surface
    );
  }
}
```

---

## Quick start — audio-only player

ExoPlayer handles audio identically to video. Simply **do not attach a texture /
do not use `ExoPlayerWidget`** — the controller's playback API is identical.

```dart
class AudioScreen extends StatefulWidget { ... }

class _AudioScreenState extends State<AudioScreen> {
  late final ExoPlayerController _ctrl;
  StreamSubscription<PlayerPosition>? _posSub;
  PlayerPosition _pos = const PlayerPosition(
    position: Duration.zero,
    buffered: Duration.zero,
    duration: Duration.zero,
  );

  @override
  void initState() {
    super.initState();
    _ctrl = ExoPlayerController();
    _init();
  }

  Future<void> _init() async {
    await _ctrl.init(); // no cacheConfig needed for simple audio

    final items = [
      MediaItemBuilder()
          .setUri('https://example.com/song1.mp3')
          .setTitle('Song 1')
          .setArtist('Artist')
          .build(),
      MediaItemBuilder()
          .setUri('https://example.com/song2.mp3')
          .setTitle('Song 2')
          .setArtist('Artist')
          .build(),
    ];
    _ctrl.setPlaylist(items);
    _ctrl.play();

    // Subscribe to position updates (fires every ~500 ms)
    _posSub = _ctrl.positionStream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _posSub?.cancel(); // cancel before disposing controller
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Track title rebuilds on every track change
          ListenableBuilder(
            listenable: _ctrl,
            builder: (_, __) => Text('Track ${_ctrl.currentMediaItemIndex + 1}'),
          ),
          // Seek bar driven by positionStream
          Slider(
            value: _pos.position.inMilliseconds.toDouble(),
            max: _pos.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
            onChanged: (v) => _ctrl.seekTo(Duration(milliseconds: v.toInt())),
          ),
          // Play / pause
          ListenableBuilder(
            listenable: _ctrl,
            builder: (_, __) => IconButton(
              icon: Icon(_ctrl.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: _ctrl.isPlaying ? _ctrl.pause : _ctrl.play,
            ),
          ),
        ],
      ),
    );
  }
}
```

See [example/lib/screens/audio_screen.dart](example/lib/screens/audio_screen.dart)
for a full example with seek bar, volume slider, shuffle, repeat, and speed controls.

---

## ExoPlayerWidget

A ready-made video player widget that renders a 16:9 surface with a built-in controls
overlay, fullscreen support, and error display.

```dart
ExoPlayerWidget(
  // ── Provide one of these two ─────────────────────────────────────────────
  initialUrl: 'https://example.com/stream.m3u8', // simple: widget owns lifecycle
  controller: myExternalCtrl,                     // advanced: you own lifecycle

  // ── Internal controller options (only when using initialUrl) ─────────────
  autoPlay: true,
  cacheConfig: const CacheConfig(maxBytes: 100 * 1024 * 1024),
  loadControlConfig: const LoadControlConfig(
    minBufferMs: 5000,
    maxBufferMs: 30000,
  ),

  // ── UI options ────────────────────────────────────────────────────────────
  showControls: true,       // show built-in play/pause/seek overlay
  allowFullscreen: true,    // show fullscreen toggle button
  fit: BoxFit.contain,      // how video is inscribed in the 16:9 box

  // ── Customisation ──────────────────────────────────────────────────────────
  placeholder: const Center(child: CircularProgressIndicator()),
  errorBuilder: (context, error) => Text('Error: ${error.message}'),
  controlsTheme: ExoPlayerControlsTheme(
    backgroundColor: Colors.black54,
    iconColor: Colors.white,
  ),

  // ── Replace the entire controls overlay ───────────────────────────────────
  overlayBuilder: (context, ctrl) => MyCustomControls(ctrl: ctrl),
)
```

> **Lifecycle rule:** When you pass an external `controller`, the widget does **not**
> call `init()` or `dispose()`. You are responsible for both. When using `initialUrl`,
> the widget manages the full lifecycle for you.

---

## ExoPlayerController

The central class. Extends `ChangeNotifier` so you can use `ListenableBuilder` to
rebuild UI whenever any observable property changes.

### Lifecycle

```dart
final ctrl = ExoPlayerController();

// 1. Always await init() before calling any playback method
await ctrl.init(
  cacheConfig: const CacheConfig(maxBytes: 200 * 1024 * 1024),
);

// 2. Load media
ctrl.setMediaUrl('https://example.com/video.mp4');

// 3. Play
ctrl.play();

// 4. Dispose when done — releases ExoPlayer, cache, textures, timers, streams
ctrl.dispose();
```

> **Important:** Always call `dispose()` in your widget's `dispose()` method.
> Failing to do so leaks JNI global references, the position timer, and (when
> caching is enabled) the `SimpleCache` directory lock.

### Playback controls

```dart
ctrl.play();
ctrl.pause();
ctrl.stop();                                    // stops and resets to idle

ctrl.seekTo(const Duration(seconds: 30));       // seek within current item
ctrl.seekToNext();                              // seek forward by seekForwardIncrement
ctrl.seekToPrevious();                          // seek back or to previous item
ctrl.seekToNextMediaItem();                     // jump to next playlist item
ctrl.seekToPreviousMediaItem();                 // jump to previous playlist item
ctrl.seekToMediaItem(2, Duration.zero);         // jump to item at index, from start
ctrl.seekToMediaItem(1, Duration(seconds: 30)); // jump to item at index, 30 s in
```

### Volume & speed

```dart
ctrl.setVolume(0.8);         // 0.0 (mute) → 1.0 (full). Reflected in ctrl.volume
ctrl.setPlaybackSpeed(1.5);  // Must be > 0. Throws ArgumentError otherwise.
                              // Reflected in ctrl.playbackSpeed
                              // Common values: 0.5, 0.75, 1.0, 1.25, 1.5, 2.0
```

### Playlists

```dart
// Replace the entire playlist (clears any previous media)
ctrl.setPlaylist([item1, item2, item3]);

// Add a single item to the end
ctrl.addMediaItem(item4);

// Remove item at index
ctrl.removeMediaItem(1);

// Jump to item at index 2, from the start
ctrl.seekToMediaItem(2, Duration.zero);

// Read the currently playing item index (0-based)
print(ctrl.currentMediaItemIndex);
```

### Repeat & shuffle

```dart
// Repeat modes
ctrl.setRepeatMode(RepeatMode.off);   // no repeat (default)
ctrl.setRepeatMode(RepeatMode.all);   // loop entire playlist
ctrl.setRepeatMode(RepeatMode.one);   // loop current item only

// Shuffle
ctrl.setShuffleModeEnabled(true);     // random playback order
ctrl.setShuffleModeEnabled(false);    // sequential order

// Read current state
print(ctrl.repeatMode);          // RepeatMode.off / .one / .all
print(ctrl.shuffleModeEnabled);  // bool
```

### Streams

`ExoPlayerController` exposes three broadcast streams. Always cancel subscriptions
in `dispose()`.

```dart
// ── Player state ─────────────────────────────────────────────────────────────
final stateSub = ctrl.stateStream.listen((ExoPlayerState state) {
  switch (state) {
    case ExoPlayerState.buffering: showSpinner();      break;
    case ExoPlayerState.ready:     hideSpinner();      break;
    case ExoPlayerState.ended:     showReplayButton(); break;
    case ExoPlayerState.idle:      break;
  }
});

// ── Position (fires every ~500 ms while playing) ──────────────────────────────
final posSub = ctrl.positionStream.listen((PlayerPosition pos) {
  // pos.position — current position
  // pos.buffered — how far ahead is buffered
  // pos.duration — total duration (Duration.zero for live streams)
  print('${pos.position} / ${pos.duration}  buffered: ${pos.buffered}');
});

// ── Playback errors ───────────────────────────────────────────────────────────
final errSub = ctrl.errorStream.listen((ExoPlaybackException e) {
  // e.errorCode — matches PlaybackException.ERROR_CODE_* constants
  // e.message   — human-readable description
  print('Error ${e.errorCode}: ${e.message}');
});

// In dispose():
stateSub.cancel();
posSub.cancel();
errSub.cancel();
```

### Reading observable state

All properties below call `notifyListeners()` when they change, so
`ListenableBuilder` rebuilds automatically.

| Property | Type | Description |
|---|---|---|
| `state` | `ExoPlayerState` | Current playback state |
| `isPlaying` | `bool` | `true` while audio/video is actively playing |
| `isLoading` | `bool` | `true` while buffering |
| `isInitialized` | `bool` | `true` after `init()` completes |
| `position` | `Duration` | Current playback position (updated by position timer) |
| `duration` | `Duration` | Total duration of current item |
| `volume` | `double` | Current volume (0.0–1.0) |
| `playbackSpeed` | `double` | Current playback speed |
| `repeatMode` | `RepeatMode` | off / one / all |
| `shuffleModeEnabled` | `bool` | Shuffle state |
| `currentMediaItemIndex` | `int` | 0-based index in the playlist |
| `videoWidth` / `videoHeight` | `int` | Video resolution (0 for audio-only) |
| `aspectRatio` | `double` | width/height ratio, falls back to 16/9 |

```dart
// Example: play/pause button that reacts to all state changes
ListenableBuilder(
  listenable: ctrl,
  builder: (context, _) {
    if (ctrl.isLoading) {
      return const CircularProgressIndicator();
    }
    return IconButton(
      icon: Icon(ctrl.isPlaying ? Icons.pause : Icons.play_arrow),
      onPressed: ctrl.isPlaying ? ctrl.pause : ctrl.play,
    );
  },
)
```

---

## MediaItem builder

Use `MediaItemBuilder` to construct a `MediaItem` with full metadata and options.
Two styles are supported — pick whichever suits your code better.

### Constructor style (all-at-once)

```dart
final item = MediaItemBuilder(
  uri: 'https://example.com/video.mp4',    // required
  title: 'My Video',
  artist: 'Artist Name',
  album: 'Album Title',
  mimeType: 'video/mp4',                   // optional — ExoPlayer auto-detects
  drmConfig: DrmConfig.widevine(
    licenseUrl: 'https://license.example.com/widevine',
    headers: {'Authorization': 'Bearer <token>'},
  ),
  clipStart: const Duration(seconds: 10),  // play only a segment
  clipEnd: const Duration(seconds: 60),
).build();
```

### Fluent style (chained setters)

```dart
final item = MediaItemBuilder()
    .setUri('https://example.com/video.mp4')    // required
    .setTitle('My Video')
    .setArtist('Artist Name')
    .setAlbum('Album Title')                    // alias for setAlbumTitle()
    .setMimeType('video/mp4')                   // optional — ExoPlayer auto-detects
    .setDrmConfig(DrmConfig.widevine(
      licenseUrl: 'https://license.example.com/widevine',
      headers: {'Authorization': 'Bearer <token>'},
    ))
    .setClipRange(                              // play only a segment
      const Duration(seconds: 10),
      const Duration(seconds: 60),
    )
    .build();
```

Both styles are interchangeable — you can also mix them (constructor sets defaults,
fluent setters override).

```dart
ctrl.setMediaItem(item);           // single item
ctrl.setPlaylist([item1, item2]);  // or a playlist
```

---

## DRM-protected content

```dart
// ── Widevine (most Android devices, works with DASH and HLS) ─────────────────
final drm = DrmConfig.widevine(
  licenseUrl: 'https://license.example.com/widevine',
  headers: {'X-Custom-Auth': 'value'},
  multiSession: true, // required for some live streams
);

// ── PlayReady ─────────────────────────────────────────────────────────────────
final drm = DrmConfig.playReady(
  licenseUrl: 'https://license.example.com/playready',
);

// ── ClearKey (testing only) ───────────────────────────────────────────────────
final drm = DrmConfig.clearKey(
  licenseUrl: 'https://keys.example.com',
);

// Apply at the media item level (recommended)
final item = MediaItemBuilder()
    .setUri('https://example.com/protected.mpd')
    .setDrmConfig(drm)
    .build();
ctrl.setMediaItem(item);

// Or apply directly when using a plain URL
ctrl.setMediaUrl('https://example.com/protected.mpd', drm: drm);
```

---

## Track selection

```dart
// Configure before init (applied at build time)
await ctrl.init(
  trackSelectorHelper: TrackSelectorHelper()
      .setPreferredAudioLanguage('en')
      .setPreferredTextLanguage('fr')
      .setMaxVideoSizeSd()         // cap resolution at 480p
      .setForceLowBitrate(true),
);

// Or change at runtime
ctrl.applyTrackSelector(
  TrackSelectorHelper()
      .setPreferredAudioLanguage('de')
      .setMaxVideoSize(1280, 720), // cap at 720p
);
```

---

## Caching

`SimpleCache` (ExoPlayer's built-in LRU cache) is enabled by passing a `CacheConfig`
to `init()`. All controller instances in the same process share one cache.

```dart
await ctrl.init(
  cacheConfig: const CacheConfig(
    maxBytes: 500 * 1024 * 1024,  // 500 MB cap
    // cacheDirectory: Directory('/custom/path'), // defaults to app cache dir
  ),
);
```

Use `CacheConfig.none` (the default) to disable caching:

```dart
await ctrl.init(); // cacheConfig defaults to CacheConfig.none
```

> **Hot-restart note:** After a Flutter hot restart the Dart VM resets but the
> Android JVM still holds the `SimpleCache` directory lock. The plugin handles this
> automatically — if creation fails it falls back to uncached playback without
> crashing. A cold restart (stop + relaunch) always clears the lock.

### Auto pre-caching for playlists

When playing a playlist, the controller can silently download the first N MB of
upcoming items in the background so that track transitions feel instantaneous.

```dart
await ctrl.init(
  cacheConfig: const CacheConfig(maxBytes: 300 * 1024 * 1024),
  autoPrecache: true,
  autoPrecacheAhead: 2,                       // download 2 items ahead
  autoPrecacheBytesPerItem: 5 * 1024 * 1024,  // 5 MB per item
);
ctrl.setPlaylistUrls(urls);  // background-downloads items 1 & 2 immediately
```

| `init()` param | Default | Description |
|---|---|---|
| `autoPrecache` | `false` | Enable/disable auto pre-caching |
| `autoPrecacheAhead` | `2` | Items ahead of current to download |
| `autoPrecacheBytesPerItem` | `3 MB` | Max bytes per item (0 = entire file) |

> **Note:** Auto pre-caching only applies when `setPlaylistUrls()` is used.
> `setPlaylist()` (which takes pre-built `MediaItem` objects) does not trigger it.

---

## Buffer tuning

Control how much media ExoPlayer pre-buffers. Reducing these values saves memory
when running multiple simultaneous players (e.g. a grid layout).

```dart
await ctrl.init(
  minBufferMs: 5000,                       // keep at least 5 s buffered
  maxBufferMs: 30000,                      // buffer up to 30 s ahead
  bufferForPlaybackMs: 1000,               // start playing after 1 s ready
  bufferForPlaybackAfterRebufferMs: 3000,  // resume after a rebuffer with 3 s ready
);

// Tighter settings for multiple simultaneous players:
await ctrl.init(minBufferMs: 2000, maxBufferMs: 8000);
```

---

## Error handling

### Automatic skip in playlist mode

When a playlist item fails, the controller automatically skips to the next item,
re-prepares, and resumes. No extra code needed.

### Manual via error stream

```dart
ctrl.errorStream.listen((ExoPlaybackException e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Playback error: ${e.message}')),
  );
});
```

### Via ExoPlayerWidget errorBuilder

```dart
ExoPlayerWidget(
  initialUrl: url,
  errorBuilder: (context, error) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 8),
        Text(error.message),
        TextButton(
          onPressed: () { /* retry logic */ },
          child: const Text('Retry'),
        ),
      ],
    ),
  ),
)
```

---

## Raw JNI access

Every Media3 ExoPlayer method is accessible directly. If a feature is not wrapped
by `ExoPlayerController`, drop down to raw JNI:

```dart
// Returns the underlying JNI ExoPlayer object
final rawPlayer = ctrl.rawPlayer;

// Example: read current MediaItem metadata
final item = rawPlayer.getCurrentMediaItem();
final title = item?.mediaMetadata?.title?.toDartString();

// Example: change track selection parameters
final params = rawPlayer.getTrackSelectionParameters();
final newParams = params.buildUpon()
    // .setPreferredAudioMimeType('audio/mp4a-latm')
    .build();
rawPlayer.setTrackSelectionParameters(newParams);

// Access the raw DefaultTrackSelector
final selector = ctrl.rawTrackSelector;
```

> **Thread safety:** ExoPlayer was built with `setLooper(Looper.getMainLooper())`.
> All JNI calls on the raw player **must** happen on the Android main thread.
> Wrap calls with the internal `_runOnMainThread` helper or post via
> `Handler(Looper.getMainLooper())` from Kotlin/Java.

---

## Project structure

```
exoplayer_jni_flutter/
├── tool/
│   └── jnigen.dart                      # JNIgen config (replaces jnigen.yaml)
├── lib/
│   ├── exoplayer_jni_flutter.dart       # Public API re-exports
│   └── src/
│       ├── exoplayer.g.dart             # GENERATED — dart run tool/jnigen.dart
│       ├── exoplayer_controller.dart    # High-level Dart wrapper (main API)
│       ├── exoplayer_widget.dart        # Drop-in video widget with controls
│       ├── media_item_builder.dart      # Fluent MediaItem builder
│       ├── track_selector_helper.dart   # Track selection helpers
│       ├── drm_config.dart              # DRM configuration
│       ├── cache_config.dart            # Cache configuration
│       └── player_state.dart            # Enums and data classes
├── android/
│   ├── build.gradle                     # Media3 AAR dependencies
│   └── src/main/kotlin/.../
│       ├── ExoplayerJniPlugin.kt        # Flutter plugin registration
│       └── ExoPlayerSurfaceBridge.kt   # Texture/Surface JNI bridge
└── example/
    └── lib/
        ├── main.dart                    # Demo app entry point
        └── screens/
            ├── audio_screen.dart        # Audio-only player with full controls
            ├── playlist_screen.dart     # Playlist + shuffle/repeat demo
            └── ...                      # Other feature demos
```

---

## Requirements

| Requirement | Minimum |
|---|---|
| Flutter | 3.22.0 |
| Dart | 3.3.0 |
| Android minSdk | 21 (Android 5.0) |
| JDK | 17 |
| CMake | 3.10+ (for JNI C bridge) |
| `clang-format` | Optional (formats generated C code) |

---

## Troubleshooting

**`gradle exited with status 1` when running jnigen**  
Run `flutter build apk` inside `example/` first to download Gradle dependencies,
then retry `dart run tool/jnigen.dart`.

**`Failed to load dynamic library 'libexoplayer_jni_flutter.so'`**  
Run `dart run jni:setup` in the project root to build the JNI native bridge.

**Player stuck on spinner after hot restart**  
Hot restart resets Dart statics but the Android JVM persists. The `SimpleCache`
directory lock may be stale. The plugin handles this automatically and falls back
to uncached playback. A cold restart (stop + relaunch) always clears the state.

**`Another SimpleCache instance uses the folder`**  
Same root cause as above. Caught automatically on `init()` — playback continues
without caching.

**Video renders black / no picture after app resume**  
The Impeller/Vulkan backend recreates surfaces when the app is backgrounded.
`ExoPlayerWidget` calls `reattachSurface()` via `WidgetsBindingObserver` automatically.
If using a raw `ExoPlayerController`, add this to your state:

```dart
class _MyState extends State<MyWidget> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _ctrl.reattachSurface();
  }
}
```

**`StateError: ExoPlayerController not initialized`**  
You called a playback method before `await ctrl.init()` finished.
Always `await init()` before any other call.

**Crash / ArgumentError when setting playback speed**  
Speed must be `> 0`. Values ≤ 0 throw `ArgumentError` before reaching ExoPlayer.

**`Intent.new$2` renamed to `Intent.new$12` after jnigen upgrade**  
Known jnigen ≥ 0.14 breaking change — overloaded method suffixes now use `$N` format.
Re-run `dart run tool/jnigen.dart` to regenerate bindings.

**`toDartString()` method not found**  
In `jni` 1.0.0+, `toDartString()` was renamed to `toString()`. Regenerate bindings.

---

## Plugin development

This section is only relevant if you are **modifying the plugin itself** —
regular app developers can ignore it.

### Regenerating JNI bindings

The JNI bindings in `lib/src/exoplayer.g.dart` are pre-generated and committed.
Only re-run this if you update the Media3 version or add new classes to
`tool/jnigen.dart`.

JNIgen needs Gradle to have already resolved the Media3 AAR classpath. Build
the example app once first:

```bash
cd example && flutter build apk && cd ..
```

Then regenerate the Dart bindings:

```bash
dart run tool/jnigen.dart
```

This overwrites `lib/src/exoplayer.g.dart` (~10 000 lines of generated Dart wrappers).
