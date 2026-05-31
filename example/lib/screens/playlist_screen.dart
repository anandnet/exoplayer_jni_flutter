/// Test 5: Playlist with next/prev, shuffle and repeat mode cycling.
///
/// Uses ExoPlayerController.setPlaylist() and addMediaItem() directly.
/// Demonstrates all four MediaItem types from the shared playlist.
library;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:exoplayer_jni_flutter/exoplayer_jni_flutter.dart';

import '../shared/constants.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late final ExoPlayerController _ctrl;
  bool _ready = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _ctrl = ExoPlayerController();
    _init();
  }

  Future<void> _init() async {
    try {
      await _ctrl.init(
        cacheConfig: const CacheConfig(maxBytes: 150 * 1024 * 1024),
      );

      // Build playlist from MediaItemBuilder
      final items = kPlaylist.map((e) {
        return MediaItemBuilder()
            .setUri(e.url)
            .setTitle(e.title)
            .setArtist(e.artist)
            .build();
      }).toList();

      _ctrl.setPlaylist(items);
      _ctrl.play();

      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _initError = e.toString());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playlist Navigation')),
      body: _initError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text('Init failed: $_initError',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            )
          : !_ready
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // ── Info ──────────────────────────────────────────────────
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('What this tests',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text(
                                '• setPlaylist() with 4 MediaItems\n'
                                '• seekToNextMediaItem / seekToPreviousMediaItem\n'
                                '• RepeatMode cycling (off → all → one)\n'
                                '• Shuffle mode toggle',
                                style: TextStyle(fontSize: 12, height: 1.6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // ── Video + built-in controls ──────────────────────────
                    ExoPlayerWidget(controller: _ctrl),
                    // ── Mode controls ─────────────────────────────────────────
                    ListenableBuilder(
                      listenable: _ctrl,
                      builder: (_, __) => _ModeBar(ctrl: _ctrl),
                    ),
                    const Divider(height: 8),
                    // ── Playlist list ─────────────────────────────────────────
                    Expanded(child: _PlaylistList(ctrl: _ctrl)),
                  ],
                ),
    );
  }
}

// ── Mode bar (repeat + shuffle) ───────────────────────────────────────────────

class _ModeBar extends StatelessWidget {
  final ExoPlayerController ctrl;
  const _ModeBar({required this.ctrl});

  static final _repeatIcons = {
    RepeatMode.off: Icons.repeat,
    RepeatMode.all: Icons.repeat_on,
    RepeatMode.one: Icons.repeat_one,
  };
  static final _repeatLabels = {
    RepeatMode.off: 'Repeat: Off',
    RepeatMode.all: 'Repeat: All',
    RepeatMode.one: 'Repeat: One',
  };
  static final _repeatNext = {
    RepeatMode.off: RepeatMode.all,
    RepeatMode.all: RepeatMode.one,
    RepeatMode.one: RepeatMode.off,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Repeat
          TextButton.icon(
            icon: Icon(_repeatIcons[ctrl.repeatMode]),
            label: Text(_repeatLabels[ctrl.repeatMode]!,
                style: const TextStyle(fontSize: 12)),
            onPressed: () => ctrl.setRepeatMode(_repeatNext[ctrl.repeatMode]!),
          ),
          const SizedBox(width: 16),
          // Shuffle
          TextButton.icon(
            icon: Icon(
              Icons.shuffle,
              color: ctrl.shuffleModeEnabled ? Colors.deepPurpleAccent : null,
            ),
            label: Text(
              ctrl.shuffleModeEnabled ? 'Shuffle: On' : 'Shuffle: Off',
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () =>
                ctrl.setShuffleModeEnabled(!ctrl.shuffleModeEnabled),
          ),
        ],
      ),
    );
  }
}

// ── Playlist list ─────────────────────────────────────────────────────────────

class _PlaylistList extends StatelessWidget {
  final ExoPlayerController ctrl;
  const _PlaylistList({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: kPlaylist.length,
      itemBuilder: (context, i) {
        final entry = kPlaylist[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.pinkAccent.withValues(alpha: 0.2),
            child: Text('${i + 1}',
                style: const TextStyle(color: Colors.pinkAccent)),
          ),
          title: Text(entry.title),
          subtitle: Text('${entry.artist} • ${entry.format}',
              style: const TextStyle(fontSize: 11)),
          onTap: () => ctrl.seekToMediaItem(i, Duration.zero),
        );
      },
    );
  }
}
