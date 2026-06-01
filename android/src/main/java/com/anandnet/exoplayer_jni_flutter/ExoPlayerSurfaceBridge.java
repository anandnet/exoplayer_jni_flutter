package com.anandnet.exoplayer_jni_flutter;

import android.view.Surface;
import io.flutter.view.TextureRegistry;

import java.util.HashMap;
import java.util.HashSet;

/**
 * Per-instance registry that lets Dart/JNI create and manage one
 * {@link TextureRegistry.SurfaceProducer} per active ExoPlayer controller.
 *
 * <p>Surface allocation is deferred to the point where each controller
 * calls {@link #createAndClaimTexture()}, rather than pre-creating a fixed
 * pool at plugin-attach time.  This eliminates the GPU-allocation race that
 * caused the last slot in the old fixed pool to always show a black screen on
 * Impeller/Vulkan.
 *
 * <p><strong>Thread safety:</strong> every method that touches a
 * {@link TextureRegistry} or a {@link TextureRegistry.SurfaceProducer}
 * <em>must</em> be called on the Android main thread.  Dart callers satisfy
 * this by wrapping the JNI call inside {@code _runOnMainThread()}.
 */
public final class ExoPlayerSurfaceBridge {

    /** Set from Kotlin at plugin-attach time; cleared at detach. */
    private static TextureRegistry sRegistry;

    /** Live producers keyed by their texture ID. */
    private static final HashMap<Long, TextureRegistry.SurfaceProducer> sProducers =
            new HashMap<>();

    /**
     * IDs whose {@code onSurfaceAvailable} fired while the producer was
     * active.  Used to trigger a re-attach after app-resume on Impeller/Vulkan.
     */
    private static final HashSet<Long> sSurfaceRefreshed = new HashSet<>();

    private ExoPlayerSurfaceBridge() {}

    // ── Called from Kotlin ────────────────────────────────────────────────

    /**
     * Called once at plugin-attach time.  Must be on the main thread.
     */
    public static synchronized void setTextureRegistry(TextureRegistry registry) {
        sRegistry = registry;
    }

    /**
     * Releases all remaining producers and clears the registry reference.
     * Called at plugin-detach time.  Must be on the main thread.
     */
    public static synchronized void disposeAll() {
        for (TextureRegistry.SurfaceProducer p : sProducers.values()) {
            p.release();
        }
        sProducers.clear();
        sSurfaceRefreshed.clear();
        sRegistry = null;
    }

    // ── Called from Dart via JNI (all on the Android main thread) ─────────

    /**
     * Creates a fresh {@link TextureRegistry.SurfaceProducer}, registers
     * Impeller/Vulkan lifecycle callbacks, and returns its texture ID.
     * Returns {@code -1} if the registry is not yet available.
     *
     * <strong>Must be called on the Android main thread</strong> because
     * {@code createSurfaceProducer()} and the resulting
     * {@code ImageReader.setOnImageAvailableListener(…, new Handler())}
     * require a thread that has called {@code Looper.prepare()}.
     */
    public static synchronized long createAndClaimTexture() {
        if (sRegistry == null) return -1L;
        final TextureRegistry.SurfaceProducer p = sRegistry.createSurfaceProducer();
        final long id = p.id();
        sProducers.put(id, p);
        p.setCallback(new TextureRegistry.SurfaceProducer.Callback() {
            @Override
            public void onSurfaceCleanup() {
                // Surface going away (app backgrounded under Impeller).
                synchronized (ExoPlayerSurfaceBridge.class) {
                    sSurfaceRefreshed.remove(id);
                }
            }

            @Override
            public void onSurfaceAvailable() {
                // Surface ready again after app-resume — flag for re-attach.
                synchronized (ExoPlayerSurfaceBridge.class) {
                    if (sProducers.containsKey(id)) {
                        sSurfaceRefreshed.add(id);
                    }
                }
            }
        });
        return id;
    }

    /**
     * Returns the current live {@link Surface} for the given texture ID by
     * delegating directly to the producer.  May allocate a new
     * {@code ImageReader} if {@code setSize} was called since the last
     * invocation, which is why this <strong>must be on the main thread</strong>
     * (the {@code ImageReader} listener uses {@code new Handler()}).
     *
     * Returns {@code null} if the producer does not exist or has been released.
     */
    public static synchronized Surface getSurface(long textureId) {
        final TextureRegistry.SurfaceProducer p = sProducers.get(textureId);
        if (p == null) return null;
        try {
            return p.getSurface();
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Returns {@code true} (and clears the flag) if {@code onSurfaceAvailable}
     * fired for this texture.  The controller should respond by calling
     * {@code setVideoSurface} again with the new surface.
     */
    public static synchronized boolean consumeSurfaceRefresh(long textureId) {
        return sSurfaceRefreshed.remove(textureId);
    }

    /**
     * Releases the {@link TextureRegistry.SurfaceProducer} for the given ID.
     * Should be called <strong>after</strong> {@code ExoPlayer.release()} so
     * that ExoPlayer has already detached from the surface.
     * Returns the released ID, or {@code -1} if not found.
     *
     * <strong>Should be called on the Android main thread.</strong>
     */
    public static synchronized long disposeTexture(long textureId) {
        final TextureRegistry.SurfaceProducer p = sProducers.remove(textureId);
        sSurfaceRefreshed.remove(textureId);
        if (p != null) {
            p.release();
            return textureId;
        }
        return -1L;
    }
}
