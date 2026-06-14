package com.anandnet.exoplayer_jni_flutter;

import android.content.Context;
import android.net.Uri;

import androidx.media3.common.C;
import androidx.media3.datasource.DataSpec;
import androidx.media3.datasource.DefaultDataSource;
import androidx.media3.datasource.DefaultHttpDataSource;
import androidx.media3.datasource.cache.CacheDataSource;
import androidx.media3.datasource.cache.CacheWriter;
import androidx.media3.datasource.cache.SimpleCache;
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

/**
 * Utility for pre-caching media URLs into a {@link SimpleCache} in the background,
 * querying cache status, and creating cache-backed media source factories.
 *
 * <p>Uses a fixed-size thread pool (2 threads) so multiple upcoming playlist items
 * can be downloaded concurrently without saturating the network.
 *
 * <p>All methods are thread-safe and safe to call from Dart via JNI.
 */
public final class PreCacheManager {

    private static final ExecutorService executor = Executors.newFixedThreadPool(2);
    private static final ConcurrentHashMap<String, Future<?>> activeTasks =
            new ConcurrentHashMap<>();

    /** Application context stored at init time for DefaultDataSource routing. */
    private static Context sAppContext;

    private PreCacheManager() {}

    /**
     * Stores the application context for use by {@link #preCacheUrl}.
     * Called automatically from {@link #createCachedMediaSourceFactory}.
     */
    public static void init(Context context) {
        if (context != null) {
            sAppContext = context.getApplicationContext();
        }
    }

    /**
     * Starts pre-caching {@code url} into {@code cache} on a background thread.
     *
     * <p>Uses {@link DefaultDataSource} which dynamically routes based on URI
     * scheme — {@code file://} goes to {@code FileDataSource}, {@code http(s)://}
     * goes to {@code DefaultHttpDataSource}, etc.
     *
     * @param cache    The {@link SimpleCache} to write into (must not be null).
     * @param url      The media URL to pre-cache.
     * @param maxBytes Maximum bytes to download. Pass {@code 0} or negative to
     *                 download the full file ({@link C#LENGTH_UNSET}).
     * @param cacheKey Optional custom cache key (e.g. a song ID). Pass {@code null}
     *                 or empty to use the URL as the cache key (default behaviour).
     */
    public static void preCacheUrl(SimpleCache cache, String url, long maxBytes,
                                   String cacheKey) {
        if (cache == null || url == null || url.isEmpty()) return;

        // Use custom key if provided, otherwise fall back to the URL.
        final String effectiveKey = (cacheKey != null && !cacheKey.isEmpty()) ? cacheKey : url;

        // Skip if a task for this key is already running.
        if (activeTasks.containsKey(effectiveKey)) return;

        final long length = (maxBytes > 0) ? maxBytes : C.LENGTH_UNSET;

        Future<?> task = executor.submit(() -> {
            try {
                // DefaultDataSource routes file:// to FileDataSource, http(s)://
                // to DefaultHttpDataSource, content:// to ContentDataSource, etc.
                CacheDataSource.Factory cacheFactory = new CacheDataSource.Factory()
                        .setCache(cache);
                if (sAppContext != null) {
                    cacheFactory.setUpstreamDataSourceFactory(
                            new DefaultDataSource.Factory(sAppContext,
                                    new DefaultHttpDataSource.Factory()));
                } else {
                    cacheFactory.setUpstreamDataSourceFactory(
                            new DefaultHttpDataSource.Factory());
                }

                CacheDataSource dataSource = cacheFactory.createDataSource();

                DataSpec.Builder specBuilder = new DataSpec.Builder()
                        .setUri(Uri.parse(url))
                        .setLength(length);

                // Set custom cache key so the cache writes under the provided key
                // instead of the raw URL (important for dynamic/tokenised URLs).
                if (cacheKey != null && !cacheKey.isEmpty()) {
                    specBuilder.setKey(cacheKey);
                }

                CacheWriter writer = new CacheWriter(dataSource, specBuilder.build(),
                        null, null);
                writer.cache();
            } catch (Exception e) {
                // Pre-cache is best-effort — silently ignore network/IO errors.
            } finally {
                activeTasks.remove(effectiveKey);
            }
        });

        activeTasks.put(effectiveKey, task);
    }

    /**
     * Backward-compatible overload without custom cache key.
     */
    public static void preCacheUrl(SimpleCache cache, String url, long maxBytes) {
        preCacheUrl(cache, url, maxBytes, null);
    }

    /**
     * Creates a {@link DefaultMediaSourceFactory} that reads from {@code cache} first,
     * falling back to the network via {@link DefaultDataSource} (which properly
     * handles {@code file://}, {@code content://}, and {@code http(s)://} URIs).
     *
     * <p>Pass the returned factory to {@code ExoPlayer.Builder.setMediaSourceFactory()} so
     * that ExoPlayer consumes data written by {@link #preCacheUrl} instead of re-downloading.
     *
     * <p>Also calls {@link #init(Context)} to store the context for pre-cache operations.
     *
     * @param context Android context (used to initialise the default extractor registry).
     * @param cache   The {@link SimpleCache} to read from / write to.
     * @return A configured {@link DefaultMediaSourceFactory}.
     */
    public static DefaultMediaSourceFactory createCachedMediaSourceFactory(
            Context context, SimpleCache cache) {
        // Store context for preCacheUrl to use DefaultDataSource routing.
        init(context);

        CacheDataSource.Factory cacheDataSourceFactory = new CacheDataSource.Factory()
                .setCache(cache)
                .setUpstreamDataSourceFactory(
                        new DefaultDataSource.Factory(context,
                                new DefaultHttpDataSource.Factory()))
                .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR);
        return new DefaultMediaSourceFactory(context)
                .setDataSourceFactory(cacheDataSourceFactory);
    }

    // ── Cache status queries ────────────────────────────────────────────────

    /**
     * Checks whether a media item is fully cached.
     *
     * @param cache      The {@link SimpleCache} instance.
     * @param urlOrKey   The URL or custom cache key used when caching the item.
     * @param contentLength The expected total content length in bytes. If unknown,
     *                      pass {@code 0} — the method then checks if any bytes
     *                      are cached at all.
     * @return {@code true} if the full content is cached (or any bytes if length unknown).
     */
    public static boolean isCached(SimpleCache cache, String urlOrKey, long contentLength) {
        if (cache == null || urlOrKey == null || urlOrKey.isEmpty()) return false;
        try {
            if (contentLength > 0) {
                // Check if all bytes from 0..contentLength are cached.
                long cachedBytes = cache.getCachedBytes(urlOrKey, 0, contentLength);
                return cachedBytes >= contentLength;
            } else {
                // Unknown length: just check if anything is cached.
                return cache.getCachedBytes(urlOrKey, 0, C.LENGTH_UNSET) > 0;
            }
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Returns the total number of cached bytes for the given URL or cache key.
     *
     * @param cache    The {@link SimpleCache} instance.
     * @param urlOrKey The URL or custom cache key.
     * @return Total cached bytes, or {@code 0} on error.
     */
    public static long getCachedBytes(SimpleCache cache, String urlOrKey) {
        if (cache == null || urlOrKey == null || urlOrKey.isEmpty()) return 0;
        try {
            return cache.getCachedBytes(urlOrKey, 0, C.LENGTH_UNSET);
        } catch (Exception e) {
            return 0;
        }
    }

    // ── Task management ─────────────────────────────────────────────────────

    /**
     * Cancels any in-progress pre-cache task for {@code url}.
     */
    public static void cancelPreCache(String url) {
        Future<?> task = activeTasks.remove(url);
        if (task != null) task.cancel(true);
    }

    /**
     * Cancels all in-progress pre-cache tasks.
     */
    public static void cancelAll() {
        for (Future<?> task : activeTasks.values()) {
            task.cancel(true);
        }
        activeTasks.clear();
    }
}
