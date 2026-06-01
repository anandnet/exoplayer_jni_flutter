package com.anandnet.exoplayer_jni_flutter;

import android.content.Context;
import android.net.Uri;

import androidx.media3.common.C;
import androidx.media3.datasource.DataSpec;
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
 * Utility for pre-caching media URLs into a {@link SimpleCache} in the background.
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

    private PreCacheManager() {}

    /**
     * Starts pre-caching {@code url} into {@code cache} on a background thread.
     *
     * @param cache    The {@link SimpleCache} to write into (must not be null).
     * @param url      The media URL to pre-cache.
     * @param maxBytes Maximum bytes to download. Pass {@code 0} or negative to
     *                 download the full file ({@link C#LENGTH_UNSET}).
     */
    public static void preCacheUrl(SimpleCache cache, String url, long maxBytes) {
        if (cache == null || url == null || url.isEmpty()) return;
        // Skip if a task for this URL is already running.
        if (activeTasks.containsKey(url)) return;

        final long length = (maxBytes > 0) ? maxBytes : C.LENGTH_UNSET;

        Future<?> task = executor.submit(() -> {
            try {
                CacheDataSource dataSource = new CacheDataSource.Factory()
                        .setCache(cache)
                        .setUpstreamDataSourceFactory(new DefaultHttpDataSource.Factory())
                        .createDataSource();

                DataSpec dataSpec = new DataSpec.Builder()
                        .setUri(Uri.parse(url))
                        .setLength(length)
                        .build();

                CacheWriter writer = new CacheWriter(dataSource, dataSpec, null, null);
                writer.cache();
            } catch (Exception e) {
                // Pre-cache is best-effort — silently ignore network/IO errors.
            } finally {
                activeTasks.remove(url);
            }
        });

        activeTasks.put(url, task);
    }

    /**
     * Creates a {@link DefaultMediaSourceFactory} that reads from {@code cache} first,
     * falling back to the network via {@link DefaultHttpDataSource}.
     *
     * <p>Pass the returned factory to {@code ExoPlayer.Builder.setMediaSourceFactory()} so
     * that ExoPlayer consumes data written by {@link #preCacheUrl} instead of re-downloading.
     *
     * @param context Android context (used to initialise the default extractor registry).
     * @param cache   The {@link SimpleCache} to read from / write to.
     * @return A configured {@link DefaultMediaSourceFactory}.
     */
    public static DefaultMediaSourceFactory createCachedMediaSourceFactory(
            Context context, SimpleCache cache) {
        CacheDataSource.Factory cacheDataSourceFactory = new CacheDataSource.Factory()
                .setCache(cache)
                .setUpstreamDataSourceFactory(new DefaultHttpDataSource.Factory())
                .setFlags(CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR);
        return new DefaultMediaSourceFactory(context)
                .setDataSourceFactory(cacheDataSourceFactory);
    }

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
