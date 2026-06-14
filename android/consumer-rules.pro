# ─── ExoPlayer JNI Flutter Plugin — Consumer ProGuard Rules ───────────────────
#
# These rules are automatically injected into the host app's ProGuard/R8
# configuration via consumerProguardFiles in build.gradle.
#
# Only classes accessed via JNI reflection from Dart (jnigen) need explicit
# keep rules — R8 cannot trace JNI calls. Normal Java→Java dependencies
# (work, startup, room) are traced automatically by R8 and already ship
# their own consumer rules in their AARs.

# ── Plugin bridge (called from Dart via JNI) ─────────────────────────────────
-keep class com.anandnet.exoplayer_jni_flutter.** { *; }

# ── Media3 classes accessed via jnigen JNI reflection ────────────────────────
# Only keep classes + nested classes ($Builder, $Listener, etc.) that jnigen
# generates bindings for. Using -keepclassmembers + -keepnames where possible
# so R8 can still shrink unused inner code paths.

# Core player
-keep class androidx.media3.exoplayer.ExoPlayer { *; }
-keep class androidx.media3.exoplayer.ExoPlayer$* { *; }

# Common data types
-keep class androidx.media3.common.MediaItem { *; }
-keep class androidx.media3.common.MediaItem$* { *; }
-keep class androidx.media3.common.MediaMetadata { *; }
-keep class androidx.media3.common.MediaMetadata$* { *; }
-keep class androidx.media3.common.PlaybackParameters { *; }
-keep class androidx.media3.common.PlaybackException { *; }
-keep class androidx.media3.common.Timeline { *; }
-keep class androidx.media3.common.Timeline$* { *; }
-keep class androidx.media3.common.TrackSelectionParameters { *; }
-keep class androidx.media3.common.TrackSelectionParameters$* { *; }
-keep class androidx.media3.common.Tracks { *; }
-keep class androidx.media3.common.Tracks$* { *; }
-keep class androidx.media3.common.VideoSize { *; }
-keep class androidx.media3.common.text.CueGroup { *; }
-keep class androidx.media3.common.Player { *; }
-keep class androidx.media3.common.Player$* { *; }

# Audio attributes (raw JNI from Dart for audio focus)
-keep class androidx.media3.common.AudioAttributes { *; }
-keep class androidx.media3.common.AudioAttributes$* { *; }
-keep class androidx.media3.common.C { *; }

# Load control
-keep class androidx.media3.exoplayer.DefaultLoadControl { *; }
-keep class androidx.media3.exoplayer.DefaultLoadControl$* { *; }

# Track selector
-keep class androidx.media3.exoplayer.trackselection.DefaultTrackSelector { *; }
-keep class androidx.media3.exoplayer.trackselection.DefaultTrackSelector$* { *; }

# Data source / cache
-keep class androidx.media3.datasource.DefaultHttpDataSource { *; }
-keep class androidx.media3.datasource.DefaultHttpDataSource$* { *; }
-keep class androidx.media3.datasource.cache.SimpleCache { *; }
-keep class androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor { *; }
-keep class androidx.media3.datasource.cache.CacheDataSource { *; }
-keep class androidx.media3.datasource.cache.CacheDataSource$* { *; }

# Media sources
-keep class androidx.media3.exoplayer.source.DefaultMediaSourceFactory { *; }
-keep class androidx.media3.exoplayer.source.ProgressiveMediaSource { *; }
-keep class androidx.media3.exoplayer.source.ProgressiveMediaSource$* { *; }
-keep class androidx.media3.exoplayer.source.MergingMediaSource { *; }
-keep class androidx.media3.exoplayer.source.ConcatenatingMediaSource2 { *; }
-keep class androidx.media3.exoplayer.source.ConcatenatingMediaSource2$* { *; }

# HLS / DASH / SmoothStreaming
-keep class androidx.media3.exoplayer.hls.HlsMediaSource { *; }
-keep class androidx.media3.exoplayer.hls.HlsMediaSource$* { *; }
-keep class androidx.media3.exoplayer.dash.DashMediaSource { *; }
-keep class androidx.media3.exoplayer.dash.DashMediaSource$* { *; }
-keep class androidx.media3.exoplayer.smoothstreaming.SsMediaSource { *; }
-keep class androidx.media3.exoplayer.smoothstreaming.SsMediaSource$* { *; }

# DRM
-keep class androidx.media3.exoplayer.drm.DefaultDrmSessionManager { *; }
-keep class androidx.media3.exoplayer.drm.DefaultDrmSessionManager$* { *; }
-keep class androidx.media3.exoplayer.drm.HttpMediaDrmCallback { *; }

# Analytics
-keep class androidx.media3.exoplayer.analytics.AnalyticsListener { *; }
-keep class androidx.media3.exoplayer.analytics.AnalyticsListener$* { *; }
-keep class androidx.media3.exoplayer.analytics.DefaultAnalyticsCollector { *; }

# ── NOT needed here (handled by their own consumer rules in their AARs) ──────
# androidx.work.**     → ships its own proguard rules
# androidx.startup.**  → ships its own proguard rules
# androidx.room.**     → ships its own proguard rules
