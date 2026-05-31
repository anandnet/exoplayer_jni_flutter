/// Audio-only playback example.
///
/// ExoPlayer handles audio the same way as video — no extra configuration.
/// We just don't attach a Texture / ExoPlayerView, so there's no video surface.
/// The controller's play/pause/seek/position APIs work identically.
library;

import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:exoplayer_jni/exoplayer_jni.dart';

import '../shared/constants.dart';

class AudioScreen extends StatefulWidget {
  const AudioScreen({super.key});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  late final ExoPlayerController _ctrl;
  bool _ready = false;
  String? _initError;

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
    try {
      await _ctrl.init();

      final items = kAudioPlaylist.map((e) {
        return MediaItemBuilder()
            .setUri(e.url)
            .setTitle(e.title)
            .setArtist(e.artist)
            .build();
      }).toList();

      _ctrl.setPlaylist(items);
      _ctrl.play();

      _posSub = _ctrl.positionStream.listen((p) {
        if (mounted) setState(() => _pos = p);
      });

      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _initError = e.toString());
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) => fmtDuration(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Player')),
      body: _initError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Init failed: $_initError',
                    style: const TextStyle(color: Colors.red)),
              ),
            )
          : !_ready
              ? const Center(child: CircularProgressIndicator())
              : _AudioPlayerUI(ctrl: _ctrl, pos: _pos, fmt: _fmt),
    );
  }
}

// ── Audio Player UI ───────────────────────────────────────────────────────────

class _AudioPlayerUI extends StatelessWidget {
  final ExoPlayerController ctrl;
  final PlayerPosition pos;
  final String Function(Duration) fmt;

  const _AudioPlayerUI({
    required this.ctrl,
    required this.pos,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final total = pos.duration.inMilliseconds.toDouble();
    final current = pos.position.inMilliseconds
        .toDouble()
        .clamp(0.0, total == 0 ? 1.0 : total);

    return Column(
      children: [
        // ── Album art placeholder ─────────────────────────────────────────
        Container(
          width: double.infinity,
          height: 200,
          color: Colors.deepPurple.withValues(alpha: 0.15),
          child: const Icon(Icons.music_note,
              size: 80, color: Colors.deepPurpleAccent),
        ),

        const SizedBox(height: 16),

        // ── Track info ────────────────────────────────────────────────────
        ListenableBuilder(
          listenable: ctrl,
          builder: (_, __) {
            final idx =
                ctrl.currentMediaItemIndex.clamp(0, kAudioPlaylist.length - 1);
            final track = kAudioPlaylist[idx];
            return Column(
              children: [
                Text(
                  track.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  track.artist,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 20),

        // ── Seek bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: current,
                  max: total == 0 ? 1 : total,
                  onChanged: (v) =>
                      ctrl.seekTo(Duration(milliseconds: v.toInt())),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(fmt(pos.position),
                        style: const TextStyle(fontSize: 12)),
                    Text(fmt(pos.duration),
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── Transport controls ────────────────────────────────────────────
        ListenableBuilder(
          listenable: ctrl,
          builder: (_, __) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 36),
                onPressed: ctrl.seekToPreviousMediaItem,
              ),
              const SizedBox(width: 8),
              // Play/pause button — shows spinner while buffering
              GestureDetector(
                onTap: ctrl.isLoading
                    ? null
                    : ctrl.isPlaying
                        ? ctrl.pause
                        : ctrl.play,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: ctrl.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.deepPurpleAccent,
                          ),
                        )
                      : Icon(
                          ctrl.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.deepPurpleAccent,
                          size: 36,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.skip_next, size: 36),
                onPressed: ctrl.seekToNextMediaItem,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── Volume ────────────────────────────────────────────────────────
        ListenableBuilder(
          listenable: ctrl,
          builder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  ctrl.volume == 0 ? Icons.volume_off : Icons.volume_up,
                  size: 20,
                ),
                Expanded(
                  child: Slider(
                    value: ctrl.volume,
                    onChanged: (v) => ctrl.setVolume(v),
                  ),
                ),
              ],
            ),
          ),
        ),

        const Divider(height: 24),

        // ── Shuffle / Repeat / Speed ──────────────────────────────────────
        ListenableBuilder(
          listenable: ctrl,
          builder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Shuffle
                IconButton(
                  icon: Icon(
                    Icons.shuffle,
                    color: ctrl.shuffleModeEnabled
                        ? Colors.deepPurpleAccent
                        : null,
                  ),
                  tooltip:
                      ctrl.shuffleModeEnabled ? 'Shuffle: On' : 'Shuffle: Off',
                  onPressed: () =>
                      ctrl.setShuffleModeEnabled(!ctrl.shuffleModeEnabled),
                ),
                // Repeat
                IconButton(
                  icon: Icon(_repeatIcon(ctrl.repeatMode)),
                  color: ctrl.repeatMode != RepeatMode.off
                      ? Colors.deepPurpleAccent
                      : null,
                  tooltip: _repeatLabel(ctrl.repeatMode),
                  onPressed: () =>
                      ctrl.setRepeatMode(_nextRepeat(ctrl.repeatMode)),
                ),
                // Speed
                _SpeedButton(ctrl: ctrl),
              ],
            ),
          ),
        ),

        const Divider(height: 8),

        // ── Playlist ──────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            itemCount: kAudioPlaylist.length,
            itemBuilder: (context, i) {
              final entry = kAudioPlaylist[i];
              return ListenableBuilder(
                listenable: ctrl,
                builder: (_, __) {
                  final isCurrent = ctrl.currentMediaItemIndex == i;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          (isCurrent ? Colors.deepPurpleAccent : Colors.grey)
                              .withValues(alpha: 0.2),
                      child: isCurrent && ctrl.isPlaying
                          ? const Icon(Icons.equalizer,
                              color: Colors.deepPurpleAccent)
                          : Text('${i + 1}',
                              style: TextStyle(
                                  color: isCurrent
                                      ? Colors.deepPurpleAccent
                                      : null)),
                    ),
                    title: Text(entry.title,
                        style: TextStyle(
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal)),
                    subtitle: Text(entry.format,
                        style: const TextStyle(fontSize: 11)),
                    onTap: () => ctrl.seekToMediaItem(i, Duration.zero),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

IconData _repeatIcon(RepeatMode mode) => switch (mode) {
      RepeatMode.off => Icons.repeat,
      RepeatMode.all => Icons.repeat_on,
      RepeatMode.one => Icons.repeat_one,
    };

String _repeatLabel(RepeatMode mode) => switch (mode) {
      RepeatMode.off => 'Repeat: Off',
      RepeatMode.all => 'Repeat: All',
      RepeatMode.one => 'Repeat: One',
    };

RepeatMode _nextRepeat(RepeatMode mode) => switch (mode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };

// ── Speed picker ──────────────────────────────────────────────────────────────

class _SpeedButton extends StatelessWidget {
  final ExoPlayerController ctrl;
  const _SpeedButton({required this.ctrl});

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final current = ctrl.playbackSpeed;
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: current != 1.0 ? Colors.deepPurpleAccent : null,
      ),
      onPressed: () => _showPicker(context),
      child: Text(
        '${current == current.truncateToDouble() ? current.toStringAsFixed(0) : current}×',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Playback Speed',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ..._speeds.map((s) => ListenableBuilder(
                  listenable: ctrl,
                  builder: (_, __) => ListTile(
                    title: Text(
                        '${s == s.truncateToDouble() ? s.toStringAsFixed(0) : s}×'),
                    trailing: ctrl.playbackSpeed == s
                        ? const Icon(Icons.check,
                            color: Colors.deepPurpleAccent)
                        : null,
                    onTap: () {
                      ctrl.setPlaybackSpeed(s);
                      Navigator.pop(context);
                    },
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
