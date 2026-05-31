/// Test 2: ExoPlayerWidget with an externally managed controller.
///
/// The screen owns the ExoPlayerController lifecycle (init + dispose).
/// ExoPlayerWidget uses it but does NOT call init/dispose.
/// Manual playback controls below the widget demonstrate direct controller use.
library;

import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:exoplayer_jni/exoplayer_jni.dart';

import '../shared/constants.dart';

class WidgetExternalScreen extends StatefulWidget {
  const WidgetExternalScreen({super.key});

  @override
  State<WidgetExternalScreen> createState() => _WidgetExternalScreenState();
}

class _WidgetExternalScreenState extends State<WidgetExternalScreen> {
  late final ExoPlayerController _ctrl;
  bool _ready = false;
  int _currentTrack = 0;
  StreamSubscription<PlayerPosition>? _posSub;
  PlayerPosition _pos = const PlayerPosition(
    position: Duration.zero,
    buffered: Duration.zero,
    duration: Duration.zero,
  );

  @override
  void initState() {
    super.initState();
    _ctrl = ExoPlayerController();
    _init();
  }

  Future<void> _init() async {
    await _ctrl.init(
      cacheConfig: const CacheConfig(maxBytes: 100 * 1024 * 1024),
    );
    _ctrl.setMediaUrl(kHlsUrl);
    _ctrl.play();
    _posSub = _ctrl.positionStream.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _ctrl.dispose(); // screen owns lifecycle
    super.dispose();
  }

  void _loadTrack(int i) {
    final urls = [kHlsUrl, kDashUrl, kMp4Url];
    _ctrl.setMediaUrl(urls[i]);
    _ctrl.play();
    setState(() => _currentTrack = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Widget — External Controller')),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Info ─────────────────────────────────────────────────
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
                            '• Screen creates & owns ExoPlayerController\n'
                            '• ExoPlayerWidget receives controller — does NOT init/dispose\n'
                            '• Manual track picker + position bar below demonstrate\n'
                            '  direct controller API alongside the widget',
                            style: TextStyle(fontSize: 12, height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Widget ───────────────────────────────────────────────
                ExoPlayerWidget(
                  controller: _ctrl,
                  showControls: true,
                  allowFullscreen: true,
                ),

                const SizedBox(height: 12),

                // ── Track picker ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Switch track (manual API)',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: Colors.blueAccent)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _TrackChip(
                              label: 'HLS',
                              active: _currentTrack == 0,
                              onTap: () => _loadTrack(0)),
                          const SizedBox(width: 8),
                          _TrackChip(
                              label: 'DASH',
                              active: _currentTrack == 1,
                              onTap: () => _loadTrack(1)),
                          const SizedBox(width: 8),
                          _TrackChip(
                              label: 'MP4',
                              active: _currentTrack == 2,
                              onTap: () => _loadTrack(2)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── Manual controls row ───────────────────────────────────
                ListenableBuilder(
                  listenable: _ctrl,
                  builder: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Position bar
                        _PositionBar(pos: _pos, ctrl: _ctrl),
                        // Play / Pause / Stop / Volume
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.replay_10),
                              onPressed: () => _ctrl.seekTo(
                                _ctrl.position - const Duration(seconds: 10),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _ctrl.isPlaying
                                    ? Icons.pause_circle
                                    : Icons.play_circle,
                                size: 44,
                              ),
                              onPressed:
                                  _ctrl.isPlaying ? _ctrl.pause : _ctrl.play,
                            ),
                            IconButton(
                              icon: const Icon(Icons.stop),
                              onPressed: _ctrl.stop,
                            ),
                            IconButton(
                              icon: const Icon(Icons.forward_10),
                              onPressed: () => _ctrl.seekTo(
                                _ctrl.position + const Duration(seconds: 10),
                              ),
                            ),
                          ],
                        ),
                        // Volume
                        Row(
                          children: [
                            const Icon(Icons.volume_up, size: 18),
                            Expanded(
                              child: Slider(
                                value: _ctrl.volume,
                                onChanged: _ctrl.setVolume,
                              ),
                            ),
                            Text(
                              '${(_ctrl.volume * 100).round()}%',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        // State chip
                        Chip(
                          label: Text(
                            _ctrl.state.name.toUpperCase(),
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor:
                              _ctrl.isPlaying ? Colors.green.shade900 : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _TrackChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TrackChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(),
    );
  }
}

class _PositionBar extends StatelessWidget {
  final PlayerPosition pos;
  final ExoPlayerController ctrl;
  const _PositionBar({required this.pos, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final total = pos.duration.inMilliseconds.toDouble();
    final current = pos.position.inMilliseconds
        .toDouble()
        .clamp(0.0, total == 0 ? 1.0 : total);
    return Row(
      children: [
        Text(fmtDuration(pos.position), style: const TextStyle(fontSize: 11)),
        Expanded(
          child: Slider(
            value: current,
            max: total == 0 ? 1 : total,
            onChanged: (v) => ctrl.seekTo(Duration(milliseconds: v.toInt())),
          ),
        ),
        Text(fmtDuration(pos.duration), style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
