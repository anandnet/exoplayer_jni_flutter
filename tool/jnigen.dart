// tool/jnigen.dart
//
// Run with:  dart run tool/jnigen.dart
//
// Before running, build the example app once so Gradle resolves all deps:
//   cd example && flutter build apk && cd ..
//
// This script generates Dart bindings for the following Media3 / ExoPlayer
// classes using JNIgen (no jnigen.yaml needed — Dart API is the new standard).

import 'dart:io';
import 'package:jnigen/jnigen.dart';
import 'package:logging/logging.dart';

void main(List<String> args) {
  final packageRoot = Platform.script.resolve('../');

  generateJniBindings(
    Config(
      // ── Output ────────────────────────────────────────────────────────────
      outputConfig: OutputConfig(
        dartConfig: DartCodeOutputConfig(
          // All bindings go into a single generated file.
          path: packageRoot.resolve('lib/src/exoplayer.g.dart'),
          structure: OutputStructure.singleFile,
        ),
      ),

      // ── Android SDK / Gradle ──────────────────────────────────────────────
      // addGradleDeps: true  → JNIgen asks Gradle for the full compile
      // classpath, which includes Media3 AARs downloaded by Gradle.
      // androidExample        → the sub-folder that contains the example app
      //                         (used to locate the Gradle project root).
      androidSdkConfig: AndroidSdkConfig(
        addGradleDeps: true,
        androidExample: 'example',
      ),

      // ── Classes to bind ───────────────────────────────────────────────────
      // List every Java/Kotlin class you want accessible from Dart.
      // JNIgen will also generate bindings for referenced types automatically.
      classes: [
        // ── Core Player ─────────────────────────────────────────────────────
        // Note: nested classes ($Builder, $Listener, etc.) are pulled
        // automatically when specifying the parent class.
        'androidx.media3.exoplayer.ExoPlayer',

        // ── Common data types ────────────────────────────────────────────────
        'androidx.media3.common.MediaItem',
        'androidx.media3.common.MediaMetadata',
        'androidx.media3.common.PlaybackParameters',
        'androidx.media3.common.Timeline',
        'androidx.media3.common.TrackSelectionParameters',
        'androidx.media3.common.Tracks',
        'androidx.media3.common.VideoSize',
        'androidx.media3.common.text.CueGroup',

        // ── Player interface + listener ───────────────────────────────────────
        'androidx.media3.common.Player',

        // ── Playback state / errors ───────────────────────────────────────────
        'androidx.media3.common.PlaybackException',

        // ── Load control ──────────────────────────────────────────────────────
        'androidx.media3.exoplayer.DefaultLoadControl',

        // ── Render / track selector ───────────────────────────────────────────
        'androidx.media3.exoplayer.trackselection.DefaultTrackSelector',

        // ── Data source (HTTP, cache) ─────────────────────────────────────────
        'androidx.media3.datasource.DefaultHttpDataSource',
        'androidx.media3.datasource.cache.SimpleCache',
        'androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor',
        'androidx.media3.datasource.cache.CacheDataSource',

        // ── Media sources ─────────────────────────────────────────────────────
        'androidx.media3.exoplayer.source.ProgressiveMediaSource',
        'androidx.media3.exoplayer.source.MergingMediaSource',
        'androidx.media3.exoplayer.source.ConcatenatingMediaSource2',

        // ── HLS ───────────────────────────────────────────────────────────────
        'androidx.media3.exoplayer.hls.HlsMediaSource',

        // ── DASH ──────────────────────────────────────────────────────────────
        'androidx.media3.exoplayer.dash.DashMediaSource',

        // ── SmoothStreaming ───────────────────────────────────────────────────
        'androidx.media3.exoplayer.smoothstreaming.SsMediaSource',

        // ── DRM ───────────────────────────────────────────────────────────────
        'androidx.media3.exoplayer.drm.DefaultDrmSessionManager',
        'androidx.media3.exoplayer.drm.HttpMediaDrmCallback',

        // ── Analytics ─────────────────────────────────────────────────────────
        'androidx.media3.exoplayer.analytics.AnalyticsListener',
        'androidx.media3.exoplayer.analytics.DefaultAnalyticsCollector',

        // ── Surface / Video output ────────────────────────────────────────────
        'android.view.Surface',
        'android.view.SurfaceHolder',

        // ── Android system types we need ──────────────────────────────────────
        'android.content.Context',
        'android.net.Uri',
        'android.os.Looper',
        'android.os.Handler',

        // ── Java types ────────────────────────────────────────────────────────
        'java.io.File',
        'java.lang.Runnable',
        'java.util.UUID',
      ],

      // ── Logging ───────────────────────────────────────────────────────────
      logLevel: Level.INFO,
    ),
  );
}
