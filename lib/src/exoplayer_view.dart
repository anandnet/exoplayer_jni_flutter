import 'package:flutter/material.dart';

import 'exoplayer_controller.dart';

/// A widget that renders ExoPlayer video output using Flutter's zero-copy
/// [Texture] compositing path.
///
/// Attach an [ExoPlayerController] (after calling `init()`) and this widget
/// will:
/// 1. Ask the plugin to allocate a [TextureRegistry] surface.
/// 2. Hand the resulting Android `Surface` to ExoPlayer via JNI.
/// 3. Display the decoded frames through a [Texture] widget.
///
/// ```dart
/// ExoPlayerView(controller: _controller)
/// ```
///
/// The aspect ratio is preserved automatically once the first frame arrives.
/// Before the surface is ready a [placeholder] is shown (defaults to a black
/// box).
class ExoPlayerView extends StatefulWidget {
  const ExoPlayerView({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
    this.placeholder,
  });

  final ExoPlayerController controller;

  /// How the video should be inscribed into its allocated space.
  final BoxFit fit;

  /// Widget to show while the surface is being initialised.
  /// Defaults to a solid black box.
  final Widget? placeholder;

  @override
  State<ExoPlayerView> createState() => _ExoPlayerViewState();
}

class _ExoPlayerViewState extends State<ExoPlayerView> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _attachIfReady();
  }

  @override
  void didUpdateWidget(ExoPlayerView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _attachIfReady();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    // Fire-and-forget — detachTexture handles its own error boundary.
    widget.controller.detachTexture();
    super.dispose();
  }

  void _attachIfReady() {
    if (widget.controller.isInitialized &&
        widget.controller.textureId == null) {
      widget.controller.attachTexture();
    }
  }

  void _onControllerChanged() {
    _attachIfReady();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final textureId = widget.controller.textureId;

    if (textureId == null) {
      return widget.placeholder ??
          AspectRatio(
            aspectRatio: widget.controller.aspectRatio,
            child: const ColoredBox(color: Colors.black),
          );
    }

    final aspectRatio = widget.controller.aspectRatio;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Texture(textureId: textureId),
    );
  }
}
