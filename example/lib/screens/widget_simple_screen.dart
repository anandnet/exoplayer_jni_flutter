/// Test 1: ExoPlayerWidget with a fully internal controller.
///
/// Nothing to set up — just pass [initialUrl] and the widget handles
/// init(), setMediaUrl(), play(), and dispose() automatically.
library;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:exoplayer_jni/exoplayer_jni.dart';

import '../shared/constants.dart';

class WidgetSimpleScreen extends StatelessWidget {
  const WidgetSimpleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Widget — Simple')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          // ── Info card ───────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What this tests',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text(
                    '• ExoPlayerWidget creates its own ExoPlayerController\n'
                    '• Lifecycle managed entirely by the widget\n'
                    '• Built-in controls: play/pause, seek, volume, speed, repeat, fullscreen\n'
                    '• Buffering spinner while loading',
                    style: TextStyle(fontSize: 12, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),

          // ── HLS player ──────────────────────────────────────────────────
          _SectionLabel('HLS stream'),
          SizedBox(height: 8),
          ExoPlayerWidget(
            initialUrl: kHlsUrl,
            autoPlay: true,
          ),
          SizedBox(height: 24),

          // ── MP4 player (autoPlay off) ────────────────────────────────
          _SectionLabel('MP4 — autoPlay: false (tap play)'),
          SizedBox(height: 8),
          ExoPlayerWidget(
            initialUrl: kMp4Url,
            autoPlay: false,
          ),
          SizedBox(height: 24),

          // ── Custom theme ─────────────────────────────────────────────
          _SectionLabel('Custom controls theme (teal accent)'),
          SizedBox(height: 8),
          ExoPlayerWidget(
            initialUrl: kMp4Url2,
            autoPlay: true,
            controlsTheme: ExoPlayerControlsTheme(
              seekActiveColor: Colors.tealAccent,
              seekThumbColor: Colors.tealAccent,
              playButtonColor: Color(0x88004D40),
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(color: Colors.deepPurpleAccent),
    );
  }
}
