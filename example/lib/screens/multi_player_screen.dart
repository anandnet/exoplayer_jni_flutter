/// Test 4: 8 simultaneous ExoPlayer instances in a scrollable 2-column grid.
///
/// Migrated from the original example/lib/main.dart MultiPlayerPage.
/// Uses compact buffer config (2s/8s) to keep per-player heap ~40 MB.
library;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:exoplayer_jni_flutter/exoplayer_jni_flutter.dart';

import '../shared/constants.dart';

// ── Player slot ───────────────────────────────────────────────────────────────

class _PlayerSlot {
  final String id;
  final String label;
  final ExoPlayerController controller;
  const _PlayerSlot(
      {required this.id, required this.label, required this.controller});
}

class MultiPlayerScreen extends StatefulWidget {
  const MultiPlayerScreen({super.key});

  @override
  State<MultiPlayerScreen> createState() => _MultiPlayerScreenState();
}

class _MultiPlayerScreenState extends State<MultiPlayerScreen> {
  static const _config = [
    ('Player A • HLS', kHlsUrl),
    ('Player B • MP4', kMp4Url),
    ('Player C • HLS', kHlsUrl),
    ('Player D • MP4', kMp4Url),
    ('Player E • HLS', kHlsUrl),
    ('Player F • MP4', kMp4Url),
    ('Player G • HLS', kHlsUrl),
    ('Player H • MP4', kMp4Url),
  ];

  static String _newId() {
    // Lightweight UUID v4 — no package dependency.
    int seed = DateTime.now().microsecondsSinceEpoch;
    int next() {
      seed ^= seed << 13;
      seed ^= seed >> 17;
      seed ^= seed << 5;
      return seed & 0xff;
    }

    final b = List<int>.generate(16, (_) => next());
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String h(int v) => v.toRadixString(16).padLeft(2, '0');
    return '${h(b[0])}${h(b[1])}${h(b[2])}${h(b[3])}-'
        '${h(b[4])}${h(b[5])}-${h(b[6])}${h(b[7])}-'
        '${h(b[8])}${h(b[9])}-'
        '${h(b[10])}${h(b[11])}${h(b[12])}${h(b[13])}${h(b[14])}${h(b[15])}';
  }

  final _slots = <_PlayerSlot>[];
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    final slots = <_PlayerSlot>[];
    for (final (label, url) in _config) {
      final c = ExoPlayerController();
      // Compact buffers: 2s/8s instead of 15s/50s — ~40 MB each vs ~100 MB.
      await c.init(
        minBufferMs: 2000,
        maxBufferMs: 8000,
        bufferForPlaybackMs: 500,
        bufferForPlaybackAfterRebufferMs: 1000,
      );
      c.setMediaUrl(url);
      c.play();
      slots.add(_PlayerSlot(id: _newId(), label: label, controller: c));
    }
    if (mounted) {
      setState(() {
        _slots.addAll(slots);
        _ready = true;
      });
    }
  }

  @override
  void dispose() {
    for (final s in _slots) {
      s.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Player — 8× simultaneous'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Play all',
            onPressed: () {
              for (final s in _slots) {
                s.controller.play();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.pause),
            tooltip: 'Pause all',
            onPressed: () {
              for (final s in _slots) {
                s.controller.pause();
              }
            },
          ),
        ],
      ),
      body: !_ready
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Initialising 8 players…',
                      style: TextStyle(fontSize: 13)),
                ],
              ),
            )
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 16 / 9,
              ),
              itemCount: _slots.length,
              itemBuilder: (context, i) {
                final slot = _slots[i];
                return RepaintBoundary(
                  key: ValueKey(slot.id),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ExoPlayerView(controller: slot.controller),
                      // Label badge
                      Positioned(
                        top: 4,
                        left: 4,
                        child: _Badge(
                          child: Text(
                            slot.label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      // State badge
                      Positioned(
                        top: 4,
                        right: 4,
                        child: _PlayerStateBadge(controller: slot.controller),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _Badge extends StatelessWidget {
  final Widget child;
  const _Badge({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }
}

class _PlayerStateBadge extends StatefulWidget {
  final ExoPlayerController controller;
  const _PlayerStateBadge({required this.controller});

  @override
  State<_PlayerStateBadge> createState() => _PlayerStateBadgeState();
}

class _PlayerStateBadgeState extends State<_PlayerStateBadge> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  void _update() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final (icon, color) = switch (c.state) {
      ExoPlayerState.ready when c.isPlaying => (
          Icons.play_arrow,
          Colors.greenAccent
        ),
      ExoPlayerState.ready => (Icons.pause, Colors.orangeAccent),
      ExoPlayerState.buffering => (Icons.hourglass_top, Colors.yellowAccent),
      ExoPlayerState.ended => (Icons.stop, Colors.redAccent),
      _ => (Icons.help_outline, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }
}
