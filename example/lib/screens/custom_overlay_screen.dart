/// Test 3: ExoPlayerWidget with a completely custom overlay.
///
/// Uses [overlayBuilder] to replace the built-in controls with a hand-crafted
/// UI that demonstrates the full controller API surface.
library;

import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:exoplayer_jni_flutter/exoplayer_jni_flutter.dart';

import '../shared/constants.dart';

class CustomOverlayScreen extends StatelessWidget {
  const CustomOverlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Widget — Custom Overlay')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What this tests',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(
                      '• overlayBuilder replaces built-in controls entirely\n'
                      '• Custom semi-transparent bottom bar with seek + buttons\n'
                      '• Speed badges tap-to-cycle\n'
                      '• Volume mute toggle',
                      style: TextStyle(fontSize: 12, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ExoPlayerWidget(
            initialUrl: kHlsUrl,
            autoPlay: true,
            showControls: false, // disable built-in
            overlayBuilder: (context, ctrl) => _MyOverlay(controller: ctrl),
          ),
        ],
      ),
    );
  }
}

// ── Custom overlay ────────────────────────────────────────────────────────────

class _MyOverlay extends StatefulWidget {
  final ExoPlayerController controller;
  const _MyOverlay({required this.controller});

  @override
  State<_MyOverlay> createState() => _MyOverlayState();
}

class _MyOverlayState extends State<_MyOverlay> {
  StreamSubscription<PlayerPosition>? _posSub;
  PlayerPosition _pos = const PlayerPosition(
    position: Duration.zero,
    buffered: Duration.zero,
    duration: Duration.zero,
  );
  bool _visible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _posSub = widget.controller.positionStream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _scheduleHide();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.controller.isPlaying) {
        setState(() => _visible = false);
      }
    });
  }

  void _show() {
    setState(() => _visible = true);
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final total = _pos.duration.inMilliseconds.toDouble();
    final current = _pos.position.inMilliseconds
        .toDouble()
        .clamp(0.0, total == 0 ? 1.0 : total);

    return GestureDetector(
      onTap: _visible ? () => setState(() => _visible = false) : _show,
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0xCC000000)],
              stops: [0.5, 1.0],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // ── Speed chips ────────────────────────────────────────────
              ListenableBuilder(
                listenable: ctrl,
                builder: (_, __) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [0.5, 1.0, 1.5, 2.0].map((s) {
                    final active = (ctrl.playbackSpeed - s).abs() < 0.05;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () {
                          ctrl.setPlaybackSpeed(s);
                          _show();
                        },
                        child: Chip(
                          label: Text('${s}x',
                              style: TextStyle(
                                fontSize: 11,
                                color: active ? Colors.black : Colors.white,
                              )),
                          backgroundColor:
                              active ? Colors.tealAccent : Colors.white24,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // ── Seek bar ───────────────────────────────────────────────
              Slider(
                value: current,
                max: total == 0 ? 1 : total,
                activeColor: Colors.tealAccent,
                inactiveColor: Colors.white38,
                onChanged: (v) {
                  _show();
                  ctrl.seekTo(Duration(milliseconds: v.toInt()));
                },
              ),
              // ── Bottom bar ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    Text(fmtDuration(_pos.position),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                    const Spacer(),
                    // Mute toggle
                    ListenableBuilder(
                      listenable: ctrl,
                      builder: (_, __) => IconButton(
                        icon: Icon(
                          ctrl.volume == 0 ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          _show();
                          ctrl.setVolume(ctrl.volume == 0 ? 1.0 : 0.0);
                        },
                      ),
                    ),
                    // Play / Pause
                    ListenableBuilder(
                      listenable: ctrl,
                      builder: (_, __) => IconButton(
                        icon: Icon(
                          ctrl.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          color: Colors.tealAccent,
                          size: 40,
                        ),
                        onPressed: () {
                          _show();
                          ctrl.isPlaying ? ctrl.pause() : ctrl.play();
                        },
                      ),
                    ),
                    const Spacer(),
                    Text(fmtDuration(_pos.duration),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
