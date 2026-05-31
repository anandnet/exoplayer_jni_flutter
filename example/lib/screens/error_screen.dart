/// Test 8: Error handling — bad URL, error stream, and errorBuilder callback.
///
/// Shows three error scenarios:
///   1. Invalid URL → ExoPlayer fires onPlayerError → ExoPlaybackException
///   2. errorBuilder callback for custom error UI
///   3. Recovering by loading a valid URL after an error
library;

import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:exoplayer_jni_flutter/exoplayer_jni_flutter.dart';

import '../shared/constants.dart';

class ErrorScreen extends StatefulWidget {
  const ErrorScreen({super.key});

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen> {
  late final ExoPlayerController _ctrl;
  bool _ready = false;
  final List<String> _log = [];
  StreamSubscription<ExoPlaybackException>? _errorSub;
  StreamSubscription<ExoPlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _ctrl = ExoPlayerController();
    _init();
  }

  Future<void> _init() async {
    await _ctrl.init();
    _stateSub = _ctrl.stateStream.listen((s) {
      if (mounted) {
        setState(() => _log.add('[${_now()}] state → ${s.name}'));
      }
    });
    _errorSub = _ctrl.errorStream.listen((e) {
      if (mounted) {
        setState(
            () => _log.add('[${_now()}] ERROR ${e.errorCode}: ${e.message}'));
      }
    });
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _errorSub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  String _now() {
    final t = DateTime.now();
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
  }

  void _loadBadUrl() {
    _log.add('[${_now()}] Loading bad URL…');
    _ctrl.setMediaUrl(kBadUrl);
    _ctrl.play();
    setState(() {});
  }

  void _recover() {
    _log.add('[${_now()}] Recovering with valid HLS URL…');
    _ctrl.setMediaUrl(kHlsUrl);
    _ctrl.play();
    setState(() {});
  }

  void _clearLog() => setState(() => _log.clear());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error Handling')),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Info ─────────────────────────────────────────────────
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('What this tests',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text(
                          '• Load a bad URL → ExoPlayer fires onPlayerError\n'
                          '• errorStream emits ExoPlaybackException\n'
                          '• ExoPlayerWidget.errorBuilder shows custom error UI\n'
                          '• Recover: load a valid URL to resume playback',
                          style: TextStyle(fontSize: 12, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Scenario 1: errorBuilder ──────────────────────────────
                const _Label('Widget with errorBuilder (custom error UI)'),
                const SizedBox(height: 8),
                ExoPlayerWidget(
                  controller: _ctrl,
                  showControls: false,
                  errorBuilder: (context, error) => _CustomErrorWidget(
                    error: error,
                    onRetry: _recover,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Action buttons ────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.broken_image),
                        label: const Text('Load bad URL'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade800,
                        ),
                        onPressed: _loadBadUrl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Recover (valid URL)'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                        ),
                        onPressed: _recover,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── State chip ────────────────────────────────────────────
                ListenableBuilder(
                  listenable: _ctrl,
                  builder: (_, __) => Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          'state: ${_ctrl.state.name}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      Chip(
                        label: Text(
                          'playing: ${_ctrl.isPlaying}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor:
                            _ctrl.isPlaying ? Colors.green.shade900 : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Event log ─────────────────────────────────────────────
                Row(
                  children: [
                    const _Label('Event log'),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.clear_all, size: 16),
                      label:
                          const Text('Clear', style: TextStyle(fontSize: 12)),
                      onPressed: _clearLog,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: _log.isEmpty
                      ? const Center(
                          child: Text('No events yet.',
                              style: TextStyle(color: Colors.white38)),
                        )
                      : ListView.builder(
                          itemCount: _log.length,
                          itemBuilder: (_, i) {
                            final isError = _log[i].contains('ERROR');
                            return Text(
                              _log[i],
                              style: TextStyle(
                                fontSize: 11,
                                color: isError
                                    ? Colors.redAccent
                                    : Colors.greenAccent,
                                fontFamily: 'monospace',
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ── Custom error widget ───────────────────────────────────────────────────────

class _CustomErrorWidget extends StatelessWidget {
  final ExoPlaybackException error;
  final VoidCallback onRetry;
  const _CustomErrorWidget({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.red.shade900.withValues(alpha: 0.85),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image, color: Colors.white, size: 48),
            const SizedBox(height: 8),
            Text(
              'Playback Error',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                error.message,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
                textAlign: TextAlign.center,
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try valid URL'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(color: Colors.redAccent),
    );
  }
}
