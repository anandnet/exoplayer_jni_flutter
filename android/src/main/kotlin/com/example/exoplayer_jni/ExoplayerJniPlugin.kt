package com.example.exoplayer_jni

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * ExoplayerJniPlugin
 *
 * Provides the [io.flutter.view.TextureRegistry] to [ExoPlayerSurfaceBridge]
 * so that Dart/JNI code can create per-player
 * [io.flutter.view.TextureRegistry.SurfaceProducer] instances on demand via
 * [ExoPlayerSurfaceBridge.createAndClaimTexture].
 *
 * Surface allocation is deferred to the point where each
 * ExoPlayerController initialises (inside a `_runOnMainThread` call), rather
 * than pre-creating a fixed pool at attach time.  Deferral eliminates the
 * GPU-allocation race that caused the last slot in the old pool to always
 * render a black screen on Impeller/Vulkan.
 */
class ExoplayerJniPlugin : FlutterPlugin {

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ExoPlayerSurfaceBridge.setTextureRegistry(binding.textureRegistry)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ExoPlayerSurfaceBridge.disposeAll()
    }
}


