/// Test 7: Navigate away and come back to verify second-visit surface rebind.
///
/// Uses the same ExoPlayerController across two pages. Pressing "Push page 2"
/// navigates forward (the surface detaches), popping returns (re-attaches).
/// Verifies the _claimedTextureId logic and reattachSurface() path.
library;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:exoplayer_jni_flutter/exoplayer_jni_flutter.dart';

import '../shared/constants.dart';

class LifecycleScreen extends StatefulWidget {
  const LifecycleScreen({super.key});

  @override
  State<LifecycleScreen> createState() => _LifecycleScreenState();
}

class _LifecycleScreenState extends State<LifecycleScreen> {
  late final ExoPlayerController _ctrl;
  bool _ready = false;
  int _pushCount = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = ExoPlayerController();
    _init();
  }

  Future<void> _init() async {
    await _ctrl.init();
    _ctrl.setMediaUrl(kMp4Url);
    _ctrl.play();
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _pushPage2() {
    setState(() => _pushCount++);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _Page2(
          controller: _ctrl,
          visitCount: _pushCount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lifecycle — Navigate & Back')),
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
                            '• Push page 2 → ExoPlayerView detaches surface\n'
                            '• Pop back → surface re-claimed via _claimedTextureId\n'
                            '• Video must resume without going black\n'
                            '• Repeat multiple times to confirm stability',
                            style: TextStyle(fontSize: 12, height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // ── Player ────────────────────────────────────────────────
                ExoPlayerView(controller: _ctrl),
                const SizedBox(height: 16),
                // ── State ─────────────────────────────────────────────────
                ListenableBuilder(
                  listenable: _ctrl,
                  builder: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _InfoChip(
                          label: 'State',
                          value: _ctrl.state.name.toUpperCase(),
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          label: 'textureId',
                          value: '${_ctrl.textureId ?? "null"}',
                          urgent: _ctrl.textureId == null,
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          label: 'pushes',
                          value: '$_pushCount',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // ── Buttons ───────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Push Page 2'),
                      onPressed: _pushPage2,
                    ),
                    const SizedBox(width: 16),
                    ListenableBuilder(
                      listenable: _ctrl,
                      builder: (_, __) => OutlinedButton.icon(
                        icon: Icon(
                            _ctrl.isPlaying ? Icons.pause : Icons.play_arrow),
                        label: Text(_ctrl.isPlaying ? 'Pause' : 'Play'),
                        onPressed: _ctrl.isPlaying ? _ctrl.pause : _ctrl.play,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Log ───────────────────────────────────────────────────
                if (_pushCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'You have navigated away $_pushCount time(s).\n'
                        'If video is visible above, the surface rebind worked.',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.greenAccent),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ── Page 2 (blank page with the same controller playing) ─────────────────────

class _Page2 extends StatelessWidget {
  final ExoPlayerController controller;
  final int visitCount;
  const _Page2({required this.controller, required this.visitCount});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Page 2 — visit #$visitCount'),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            const Text(
              'Player is running in the background.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Press ← Back to return.\nThe video surface should re-attach.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 32),
            ListenableBuilder(
              listenable: controller,
              builder: (_, __) => Chip(
                label: Text(
                  'textureId = ${controller.textureId ?? "null (detached)"}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chip helper ───────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final bool urgent;
  const _InfoChip(
      {required this.label, required this.value, this.urgent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:
            urgent ? Colors.red.shade900 : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(color: Colors.white54)),
            TextSpan(
                text: value,
                style: TextStyle(
                    color: urgent ? Colors.redAccent : Colors.white,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
