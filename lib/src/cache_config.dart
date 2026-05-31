import 'dart:io';

/// Configuration for ExoPlayer's [SimpleCache] + [CacheDataSource].
///
/// Pass this to [ExoPlayerController.init] to enable local media caching.
class CacheConfig {
  /// Directory where cached media is stored.
  /// Defaults to `<cacheDir>/exoplayer_cache` if not provided.
  final Directory? cacheDirectory;

  /// Maximum total cache size in bytes.
  /// Defaults to 500 MB.
  final int maxBytes;

  const CacheConfig({
    this.cacheDirectory,
    this.maxBytes = 500 * 1024 * 1024, // 500 MB
  });

  /// Convenience: no cache (default upstream behaviour).
  static const CacheConfig none = CacheConfig(maxBytes: 0);
}
