/// Test 6: Performance monitoring and JNI stress test.
///
/// Shows frame timing (build/raster), RSS memory, JNI callback throughput,
/// and a rapid-seek stress mode that hammers the JNI call path.
///
/// Migrated from the original example/lib/main.dart.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' show FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:exoplayer_jni_flutter/exoplayer_jni_flutter.dart';

import '../shared/constants.dart';

class PerfScreen extends StatefulWidget {
  const PerfScreen({super.key});

  @override
  State<PerfScreen> createState() => _PerfScreenState();
}

class _PerfScreenState extends State<PerfScreen> {
  late final ExoPlayerController _ctrl;
  bool _ready = false;
  String? _error;

  // ── Frame timing ─────────────────────────────────────────────────────────
  final _frameBuf = <FrameTiming>[];
  _FrameStats _stats = const _FrameStats();
  int _totalFrames = 0;
  int _totalJank = 0;

  // ── Memory ────────────────────────────────────────────────────────────────
  int _rss = 0;
  int _peakRss = 0;

  // ── Counters ──────────────────────────────────────────────────────────────
  int _jniEvents = 0;

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _refreshTimer;
  bool _stressActive = false;
  Timer? _stressTimer;

  // ── Flutter perf overlay ──────────────────────────────────────────────────
  final _perfOverlay = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addTimingsCallback(_onFrameTimings);
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _refresh();
    });
    _ctrl = ExoPlayerController();
    _init();
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    _frameBuf.addAll(timings);
    if (_frameBuf.length > 120) {
      _frameBuf.removeRange(0, _frameBuf.length - 120);
    }
    _totalFrames += timings.length;
    _totalJank += timings.where((t) => t.totalSpan.inMilliseconds > 16).length;
  }

  void _refresh() {
    _rss = ProcessInfo.currentRss;
    if (_rss > _peakRss) _peakRss = _rss;
    if (_frameBuf.isNotEmpty) {
      final n = _frameBuf.length;
      double sumB = 0, sumR = 0, worst = 0;
      int jank = 0;
      for (final t in _frameBuf) {
        final b = t.buildDuration.inMicroseconds / 1000.0;
        final r = t.rasterDuration.inMicroseconds / 1000.0;
        final total = t.totalSpan.inMicroseconds / 1000.0;
        sumB += b;
        sumR += r;
        if (total > worst) worst = total;
        if (total > 16.67) jank++;
      }
      _stats = _FrameStats(
        avgBuild: sumB / n,
        avgRaster: sumR / n,
        worst: worst,
        windowJank: jank,
        windowSize: n,
      );
    }
    setState(() {});
  }

  Future<void> _init() async {
    await _ctrl.init();
    _ctrl.stateStream.listen((_) {
      if (mounted) setState(() => _jniEvents++);
    });
    _ctrl.errorStream.listen((e) {
      if (mounted) setState(() => _error = e.message);
    });
    _ctrl.setMediaUrl(kHlsUrl);
    _ctrl.play();
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeTimingsCallback(_onFrameTimings);
    _refreshTimer?.cancel();
    _stressTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleStress() {
    setState(() => _stressActive = !_stressActive);
    if (_stressActive) {
      _stressTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!_ctrl.isInitialized) return;
        final ms = _ctrl.duration.inMilliseconds;
        if (ms <= 0) return;
        final target = DateTime.now().millisecondsSinceEpoch % ms;
        _ctrl.seekTo(Duration(milliseconds: target));
      });
    } else {
      _stressTimer?.cancel();
      _stressTimer = null;
    }
  }

  void _resetCounters() {
    _frameBuf.clear();
    _stats = const _FrameStats();
    _totalFrames = 0;
    _totalJank = 0;
    _jniEvents = 0;
    _rss = ProcessInfo.currentRss;
    _peakRss = 0;
    setState(() {});
  }

  static String _mb(int b) => '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  static String _ms(double ms) => '${ms.toStringAsFixed(1)} ms';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance & Stress'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _perfOverlay,
            builder: (_, active, __) => IconButton(
              icon:
                  Icon(Icons.speed, color: active ? Colors.orangeAccent : null),
              tooltip: 'Flutter GPU/UI overlay',
              onPressed: () => _perfOverlay.value = !_perfOverlay.value,
            ),
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (kDebugMode)
                  Container(
                    color: Colors.orange.shade900,
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: const Text(
                      '⚠  DEBUG build — use --profile for real metrics',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                // ── Player ────────────────────────────────────────────────
                RepaintBoundary(
                  child: ExoPlayerView(controller: _ctrl),
                ),
                if (_error != null)
                  Container(
                    width: double.infinity,
                    color: Colors.red.shade900,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text(_error!, style: const TextStyle(fontSize: 12)),
                  ),
                // ── Stats panel ───────────────────────────────────────────
                Container(
                  width: double.infinity,
                  color: Colors.black87,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.7,
                    ),
                    child: ListenableBuilder(
                      listenable: _ctrl,
                      builder: (_, __) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Memory  cur ${_mb(_rss)}   peak ${_mb(_peakRss)}'),
                          Text(
                            'Frame   build ${_ms(_stats.avgBuild)}  '
                            'raster ${_ms(_stats.avgRaster)}  '
                            'worst ${_ms(_stats.worst)}',
                          ),
                          Text(
                            'Jank    window ${_stats.windowJank}/${_stats.windowSize}  '
                            'session $_totalJank/$_totalFrames '
                            '(${_totalFrames == 0 ? 0 : (_totalJank / _totalFrames * 100).toStringAsFixed(1)}%)',
                          ),
                          Text('JNI→Dart  $_jniEvents state events'),
                          Text(
                            'Player  ${_ctrl.state.name.toUpperCase()}'
                            '  ${_ctrl.videoWidth}×${_ctrl.videoHeight}'
                            '  ${fmtDuration(_ctrl.position)} / ${fmtDuration(_ctrl.duration)}',
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _SmallBtn(
                                label: _stressActive
                                    ? 'Stop stress'
                                    : 'Seek stress',
                                icon:
                                    _stressActive ? Icons.stop : Icons.flash_on,
                                color: _stressActive
                                    ? Colors.redAccent
                                    : Colors.greenAccent,
                                onTap: _toggleStress,
                              ),
                              const SizedBox(width: 8),
                              _SmallBtn(
                                label: 'Reset',
                                icon: Icons.refresh,
                                color: Colors.white54,
                                onTap: _resetCounters,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // ── Speed + volume ────────────────────────────────────────
                ListenableBuilder(
                  listenable: _ctrl,
                  builder: (_, __) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.speed, size: 18),
                            const SizedBox(width: 4),
                            Text('${_ctrl.playbackSpeed.toStringAsFixed(2)}×',
                                style: const TextStyle(fontSize: 12)),
                            Expanded(
                              child: Slider(
                                value: _ctrl.playbackSpeed.clamp(0.25, 3.0),
                                min: 0.25,
                                max: 3.0,
                                divisions: 11,
                                onChanged: _ctrl.setPlaybackSpeed,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.volume_up, size: 18),
                            Expanded(
                              child: Slider(
                                value: _ctrl.volume,
                                onChanged: _ctrl.setVolume,
                              ),
                            ),
                          ],
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

// ── Helpers ───────────────────────────────────────────────────────────────────

class _FrameStats {
  final double avgBuild;
  final double avgRaster;
  final double worst;
  final int windowJank;
  final int windowSize;

  const _FrameStats({
    this.avgBuild = 0,
    this.avgRaster = 0,
    this.worst = 0,
    this.windowJank = 0,
    this.windowSize = 0,
  });
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SmallBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 13, color: color),
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        visualDensity: VisualDensity.compact,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
