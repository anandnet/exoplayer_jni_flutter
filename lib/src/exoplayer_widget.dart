import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';

import 'exoplayer_controller.dart';

/// A full-featured video player widget wrapping [ExoPlayerController].
///
/// ### Basic usage (internal controller)
/// ```dart
/// ExoPlayerWidget(
///   initialUrl: 'https://example.com/video.m3u8',
///   autoPlay: true,
/// )
/// ```
///
/// ### Advanced usage (external controller)
/// ```dart
/// final ctrl = ExoPlayerController();
/// await ctrl.init();
/// ctrl.setMediaUrl('https://example.com/video.m3u8');
///
/// ExoPlayerWidget(controller: ctrl)
/// ```
///
/// When [controller] is provided the widget does **not** call `init()` or
/// `dispose()` — the caller owns the lifecycle.
///
/// When [controller] is omitted an internal controller is created from the
/// supplied [initialUrl] / [cacheConfig] / [loadControlConfig] and disposed
/// when the widget is removed from the tree.
class ExoPlayerWidget extends StatefulWidget {
  const ExoPlayerWidget({
    super.key,
    // ── external controller (optional) ───────────────────────────────────────
    this.controller,
    // ── internal controller options (used when controller == null) ───────────
    this.initialUrl,
    this.cacheConfig = CacheConfig.none,
    this.loadControlConfig = const LoadControlConfig(),
    this.autoPlay = true,
    // ── UI options ────────────────────────────────────────────────────────────
    this.showControls = true,
    this.allowFullscreen = true,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorBuilder,
    this.controlsTheme,
    // ── custom controls overlay ───────────────────────────────────────────────
    this.overlayBuilder,
  }) : assert(
          controller != null || initialUrl != null,
          'Provide either a controller or an initialUrl.',
        );

  /// External controller. When supplied the widget renders its state but does
  /// not manage the lifecycle (no `init()` / `dispose()` calls).
  final ExoPlayerController? controller;

  // ── Internal controller options ──────────────────────────────────────────

  /// Media URL to load when no [controller] is supplied.
  final String? initialUrl;

  /// Cache configuration for the internal controller.
  final CacheConfig cacheConfig;

  /// Load-control buffer tuning for the internal controller.
  final LoadControlConfig loadControlConfig;

  /// Whether to call `play()` immediately after the internal controller is
  /// ready.
  final bool autoPlay;

  // ── UI ───────────────────────────────────────────────────────────────────

  /// Whether to overlay the built-in playback controls.
  final bool showControls;

  /// Whether to show the fullscreen toggle button.
  final bool allowFullscreen;

  /// How the video frame should be inscribed into its allocated box.
  final BoxFit fit;

  /// Widget to show while the surface is initialising.
  final Widget? placeholder;

  /// Builder called when ExoPlayer reports a playback error.
  /// Receives the [ExoPlaybackException]; return a widget to display it.
  final Widget Function(BuildContext, ExoPlaybackException)? errorBuilder;

  /// Theme overrides for the built-in controls. When null, defaults derived
  /// from [Theme.of(context)] are used.
  final ExoPlayerControlsTheme? controlsTheme;

  /// Custom overlay builder that replaces the built-in controls entirely.
  /// The widget returned is positioned over the video surface.
  /// [controller] is the active controller (internal or external).
  final Widget Function(BuildContext context, ExoPlayerController controller)?
      overlayBuilder;

  @override
  State<ExoPlayerWidget> createState() => _ExoPlayerWidgetState();
}

// ─────────────────────────────────────────────────────────────────────────────

class _ExoPlayerWidgetState extends State<ExoPlayerWidget>
    with WidgetsBindingObserver {
  ExoPlayerController? _internalController;
  bool _ownsController = false;

  ExoPlayerController get _ctrl => widget.controller ?? _internalController!;

  // ── UI state ──────────────────────────────────────────────────────────────
  bool _controlsVisible = true;
  Timer? _controlsHideTimer;
  bool _seeking = false;
  double _seekValue = 0.0;
  ExoPlaybackException? _lastError;

  // ── Stream subscriptions ─────────────────────────────────────────────────
  StreamSubscription<ExoPlaybackException>? _errorSub;
  StreamSubscription<ExoPlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  @override
  void didUpdateWidget(ExoPlayerWidget old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller ||
        old.initialUrl != widget.initialUrl) {
      _teardown();
      _setup();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _teardown();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ctrl.reattachSurface();
    }
  }

  // ── Setup / teardown ─────────────────────────────────────────────────────

  Future<void> _setup() async {
    if (widget.controller != null) {
      // External — just listen for errors.
      _ownsController = false;
      _subscribeErrors(_ctrl);
      await _ctrl.attachTexture();
      if (mounted) setState(() {});
      return;
    }

    // Internal — create, init, load, play.
    _ownsController = true;
    final ctrl = ExoPlayerController();
    _internalController = ctrl;

    await ctrl.init(
      cacheConfig: widget.cacheConfig,
      minBufferMs: widget.loadControlConfig.minBufferMs,
      maxBufferMs: widget.loadControlConfig.maxBufferMs,
      bufferForPlaybackMs: widget.loadControlConfig.bufferForPlaybackMs,
      bufferForPlaybackAfterRebufferMs:
          widget.loadControlConfig.bufferForPlaybackAfterRebufferMs,
    );

    if (!mounted) {
      ctrl.dispose();
      return;
    }

    ctrl.setMediaUrl(widget.initialUrl!);
    if (widget.autoPlay) ctrl.play();

    await ctrl.attachTexture();
    _subscribeErrors(ctrl);
    if (mounted) setState(() {});
  }

  void _subscribeErrors(ExoPlayerController ctrl) {
    _errorSub?.cancel();
    _stateSub?.cancel();
    _errorSub = ctrl.errorStream.listen((e) {
      if (mounted) setState(() => _lastError = e);
    });
    // Clear error when the player recovers (buffering = new media preparing).
    _stateSub = ctrl.stateStream.listen((s) {
      if (mounted &&
          _lastError != null &&
          (s == ExoPlayerState.buffering || s == ExoPlayerState.ready)) {
        setState(() => _lastError = null);
      }
    });
  }

  void _teardown() {
    _controlsHideTimer?.cancel();
    _errorSub?.cancel();
    _stateSub?.cancel();
    if (_ownsController) {
      _internalController?.dispose();
    }
    _internalController = null;
    _ownsController = false;
    _lastError = null;
  }

  // ── Controls visibility ──────────────────────────────────────────────────

  void _showControls() {
    _controlsHideTimer?.cancel();
    setState(() => _controlsVisible = true);
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _ctrl.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _controlsHideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  // ── Fullscreen ───────────────────────────────────────────────────────────

  void _enterFullscreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenPage(
          controller: _ctrl,
          fit: widget.fit,
          controlsTheme: widget.controlsTheme,
          overlayBuilder: widget.overlayBuilder,
        ),
      ),
    )
        .then((_) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_ctrl.isInitialized) {
      return widget.placeholder ??
          const AspectRatio(
            aspectRatio: 16.0 / 9.0,
            child: ColoredBox(color: Colors.black),
          );
    }

    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        // Show errorBuilder if present and error is active.
        if (_lastError != null && widget.errorBuilder != null) {
          return widget.errorBuilder!(context, _lastError!);
        }

        return AspectRatio(
          aspectRatio: 16.0 / 9.0,
          child: GestureDetector(
            onTap: _toggleControls,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Video surface: always fills the 16:9 container, video
                // is inscribed using [widget.fit] (default BoxFit.contain).
                SizedBox.expand(
                  child: _ctrl.textureId != null
                      ? FittedBox(
                          fit: widget.fit,
                          child: SizedBox(
                            width: _ctrl.videoWidth > 0
                                ? _ctrl.videoWidth.toDouble()
                                : 1920,
                            height: _ctrl.videoHeight > 0
                                ? _ctrl.videoHeight.toDouble()
                                : 1080,
                            child: Texture(textureId: _ctrl.textureId!),
                          ),
                        )
                      : (widget.placeholder ??
                          const ColoredBox(color: Colors.black)),
                ),
                if (_lastError != null && widget.errorBuilder == null)
                  _DefaultError(error: _lastError!),
                if (widget.overlayBuilder != null)
                  Positioned.fill(
                    child: widget.overlayBuilder!(context, _ctrl),
                  )
                else if (widget.showControls)
                  AnimatedOpacity(
                    opacity: _controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: _Controls(
                      controller: _ctrl,
                      theme: widget.controlsTheme ??
                          ExoPlayerControlsTheme.fromContext(context),
                      allowFullscreen: widget.allowFullscreen,
                      onFullscreen: _enterFullscreen,
                      onUserInteraction: _showControls,
                      seeking: _seeking,
                      seekValue: _seekValue,
                      onSeekStart: (v) => setState(() {
                        _seeking = true;
                        _seekValue = v;
                      }),
                      onSeekChanged: (v) => setState(() => _seekValue = v),
                      onSeekEnd: (v) {
                        setState(() => _seeking = false);
                        final dur = _ctrl.duration;
                        if (dur > Duration.zero) {
                          _ctrl.seekTo(
                            Duration(
                                milliseconds: (v * dur.inMilliseconds).round()),
                          );
                        }
                      },
                    ),
                  ),
              ],
            ),
          ), // AspectRatio
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Controls overlay
// ─────────────────────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.theme,
    required this.allowFullscreen,
    required this.onFullscreen,
    required this.onUserInteraction,
    required this.seeking,
    required this.seekValue,
    required this.onSeekStart,
    required this.onSeekChanged,
    required this.onSeekEnd,
  });

  final ExoPlayerController controller;
  final ExoPlayerControlsTheme theme;
  final bool allowFullscreen;
  final VoidCallback onFullscreen;
  final VoidCallback onUserInteraction;
  final bool seeking;
  final double seekValue;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekChanged;
  final ValueChanged<double> onSeekEnd;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final pos = controller.position;
    final dur = controller.duration;
    final progress = (dur > Duration.zero && !seeking)
        ? pos.inMilliseconds / dur.inMilliseconds
        : seekValue;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x88000000), Color(0x00000000), Color(0xAA000000)],
          stops: [0.0, 0.4, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // ── Top bar ────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _IconBtn(
                icon: Icons.speed,
                color: theme.iconColor,
                tooltip: 'Speed',
                onTap: () {
                  onUserInteraction();
                  _showSpeedDialog(context);
                },
              ),
              _IconBtn(
                icon: _repeatIcon(controller.repeatMode),
                color: theme.iconColor,
                tooltip: 'Repeat',
                onTap: () {
                  onUserInteraction();
                  controller.setRepeatMode(_nextRepeat(controller.repeatMode));
                },
              ),
              if (allowFullscreen)
                _IconBtn(
                  icon: Icons.fullscreen,
                  color: theme.iconColor,
                  tooltip: 'Fullscreen',
                  onTap: () {
                    onUserInteraction();
                    onFullscreen();
                  },
                ),
            ],
          ),

          // ── Centre play/pause + skip ───────────────────────────────────────
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _IconBtn(
                    icon: Icons.skip_previous,
                    color: theme.iconColor,
                    size: 36,
                    onTap: () {
                      onUserInteraction();
                      controller.seekToPreviousMediaItem();
                    },
                  ),
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: () {
                      onUserInteraction();
                      controller.isPlaying
                          ? controller.pause()
                          : controller.play();
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.playButtonColor,
                        shape: BoxShape.circle,
                      ),
                      child: controller.isLoading
                          ? Padding(
                              padding: const EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: theme.iconColor,
                              ),
                            )
                          : Icon(
                              controller.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: theme.iconColor,
                              size: 32,
                            ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  _IconBtn(
                    icon: Icons.skip_next,
                    color: theme.iconColor,
                    size: 36,
                    onTap: () {
                      onUserInteraction();
                      controller.seekToNextMediaItem();
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom: seek bar + time + volume ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Seek bar
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: theme.seekActiveColor,
                    inactiveTrackColor: theme.seekInactiveColor,
                    thumbColor: theme.seekThumbColor,
                    overlayShape: SliderComponentShape.noOverlay,
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChangeStart: (v) {
                      onUserInteraction();
                      onSeekStart(v);
                    },
                    onChanged: (v) {
                      onUserInteraction();
                      onSeekChanged(v);
                    },
                    onChangeEnd: onSeekEnd,
                  ),
                ),
                // Time row: pos | spacer | vol | duration
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Text(
                        _fmt(pos),
                        style: TextStyle(color: theme.textColor, fontSize: 12),
                      ),
                      const Spacer(),
                      Icon(
                        controller.volume == 0
                            ? Icons.volume_off
                            : Icons.volume_up,
                        color: theme.iconColor,
                        size: 18,
                      ),
                      SizedBox(
                        width: 80,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: theme.seekActiveColor,
                            inactiveTrackColor: theme.seekInactiveColor,
                            thumbColor: theme.seekThumbColor,
                            overlayShape: SliderComponentShape.noOverlay,
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5),
                          ),
                          child: Slider(
                            value: controller.volume,
                            onChanged: (v) {
                              onUserInteraction();
                              controller.setVolume(v);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _fmt(dur),
                        style: TextStyle(color: theme.textColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSpeedDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _SpeedSheet(controller: controller),
    );
  }

  static IconData _repeatIcon(RepeatMode mode) => switch (mode) {
        RepeatMode.off => Icons.repeat,
        RepeatMode.one => Icons.repeat_one,
        RepeatMode.all => Icons.repeat_on,
      };

  static RepeatMode _nextRepeat(RepeatMode mode) => switch (mode) {
        RepeatMode.off => RepeatMode.all,
        RepeatMode.all => RepeatMode.one,
        RepeatMode.one => RepeatMode.off,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Speed sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SpeedSheet extends StatelessWidget {
  const _SpeedSheet({required this.controller});
  final ExoPlayerController controller;

  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text('Playback speed',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final s in _speeds)
            ListTile(
              title: Text('${s}x'),
              trailing: controller.playbackSpeed == s
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                controller.setPlaybackSpeed(s);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fullscreen page
// ─────────────────────────────────────────────────────────────────────────────

class _FullscreenPage extends StatefulWidget {
  const _FullscreenPage({
    required this.controller,
    required this.fit,
    required this.controlsTheme,
    required this.overlayBuilder,
  });

  final ExoPlayerController controller;
  final BoxFit fit;
  final ExoPlayerControlsTheme? controlsTheme;
  final Widget Function(BuildContext, ExoPlayerController)? overlayBuilder;

  @override
  State<_FullscreenPage> createState() => _FullscreenPageState();
}

class _FullscreenPageState extends State<_FullscreenPage> {
  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _seeking = false;
  double _seekValue = 0.0;

  void _showControls() {
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.controller.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    _controlsVisible
        ? setState(() => _controlsVisible = false)
        : _showControls();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          return GestureDetector(
            onTap: _toggleControls,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: FittedBox(
                    fit: widget.fit,
                    child: SizedBox(
                      width: widget.controller.videoWidth > 0
                          ? widget.controller.videoWidth.toDouble()
                          : 1920,
                      height: widget.controller.videoHeight > 0
                          ? widget.controller.videoHeight.toDouble()
                          : 1080,
                      child: widget.controller.textureId != null
                          ? Texture(textureId: widget.controller.textureId!)
                          : const ColoredBox(color: Colors.black),
                    ),
                  ),
                ),
                if (widget.overlayBuilder != null)
                  Positioned.fill(
                    child: widget.overlayBuilder!(context, widget.controller),
                  )
                else
                  AnimatedOpacity(
                    opacity: _controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: _Controls(
                      controller: widget.controller,
                      theme: widget.controlsTheme ??
                          ExoPlayerControlsTheme.fromContext(context),
                      allowFullscreen: true,
                      onFullscreen: () => Navigator.of(context).pop(),
                      onUserInteraction: _showControls,
                      seeking: _seeking,
                      seekValue: _seekValue,
                      onSeekStart: (v) => setState(() {
                        _seeking = true;
                        _seekValue = v;
                      }),
                      onSeekChanged: (v) => setState(() => _seekValue = v),
                      onSeekEnd: (v) {
                        setState(() => _seeking = false);
                        final dur = widget.controller.duration;
                        if (dur > Duration.zero) {
                          widget.controller.seekTo(
                            Duration(
                                milliseconds: (v * dur.inMilliseconds).round()),
                          );
                        }
                      },
                    ),
                  ),
                // Back button in fullscreen
                Positioned(
                  top: 8,
                  left: 4,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: IconButton(
                      icon: const Icon(Icons.fullscreen_exit,
                          color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Default error display
// ─────────────────────────────────────────────────────────────────────────────

class _DefaultError extends StatelessWidget {
  const _DefaultError({required this.error});
  final ExoPlaybackException error;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          Text(
            error.message,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small icon button helper
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.color,
    this.size = 24,
    this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final double size;
  final String? tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color, size: size),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme
// ─────────────────────────────────────────────────────────────────────────────

/// Visual configuration for [ExoPlayerWidget]'s built-in controls overlay.
class ExoPlayerControlsTheme {
  const ExoPlayerControlsTheme({
    this.iconColor = Colors.white,
    this.textColor = Colors.white,
    this.playButtonColor = const Color(0x66000000),
    this.seekActiveColor = Colors.white,
    this.seekInactiveColor = const Color(0x66FFFFFF),
    this.seekThumbColor = Colors.white,
  });

  /// Derives defaults from the app's [ThemeData].
  factory ExoPlayerControlsTheme.fromContext(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExoPlayerControlsTheme(
      seekActiveColor: scheme.primary,
      seekThumbColor: scheme.primary,
    );
  }

  final Color iconColor;
  final Color textColor;
  final Color playButtonColor;
  final Color seekActiveColor;
  final Color seekInactiveColor;
  final Color seekThumbColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Load control configuration
// ─────────────────────────────────────────────────────────────────────────────

/// Buffer-tuning parameters forwarded to [ExoPlayerController.init].
class LoadControlConfig {
  const LoadControlConfig({
    this.minBufferMs = 15000,
    this.maxBufferMs = 50000,
    this.bufferForPlaybackMs = 1500,
    this.bufferForPlaybackAfterRebufferMs = 5000,
  });

  final int minBufferMs;
  final int maxBufferMs;
  final int bufferForPlaybackMs;
  final int bufferForPlaybackAfterRebufferMs;
}
