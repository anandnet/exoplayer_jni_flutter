/// Auto pre-cache demo screen.
///
/// Demonstrates [ExoPlayerController.init] with `autoPrecache: true`.
/// While item N plays, the controller silently downloads the first
/// [autoPrecacheAhead] megabytes of items N+1 and N+2 so that track
/// transitions feel instantaneous.
library;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:exoplayer_jni_flutter/exoplayer_jni_flutter.dart';

import '../shared/constants.dart';

class PrecacheScreen extends StatefulWidget {
  const PrecacheScreen({super.key});

  @override
  State<PrecacheScreen> createState() => _PrecacheScreenState();
}

class _PrecacheScreenState extends State<PrecacheScreen> {
  late final ExoPlayerController _ctrl;
  bool _ready = false;
  String? _initError;

  static const _ahead = 2; // items to pre-cache ahead
  static const _bytesPerItem = 5 * 1024 * 1024; // 5 MB per item

  @override
  void initState() {
    super.initState();
    _ctrl = ExoPlayerController();
    _init();
  }

  Future<void> _init() async {
    try {
      await _ctrl.init(
        cacheConfig: const CacheConfig(maxBytes: 300 * 1024 * 1024),
        autoPrecache: true,
        autoPrecacheAhead: _ahead,
        autoPrecacheBytesPerItem: _bytesPerItem,
      );
      _ctrl.setPlaylistUrls(kPlaylist.map((e) => e.url).toList());
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
    if (_initError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Auto Pre-Cache')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Init failed: $_initError',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_ready) {
      return Scaffold(
        appBar: AppBar(title: const Text('Auto Pre-Cache')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Auto Pre-Cache')),
      body: Column(
        children: [
          // ── Info card ────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What this demonstrates',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• autoPrecache=true, autoPrecacheAhead=2\n'
                      '• setPlaylistUrls() — background-downloads the next 2 items\n'
                      '• 5 MB cached per item → instant track transitions\n'
                      '• Pre-cache advances automatically as playback progresses',
                      style: TextStyle(fontSize: 12, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Player widget ─────────────────────────────────────────────────
          ExoPlayerWidget(controller: _ctrl),

          // ── Pre-cache status bar ──────────────────────────────────────────
          ListenableBuilder(
            listenable: _ctrl,
            builder: (_, __) => _PrecacheStatusBar(
              currentIndex: _ctrl.currentMediaItemIndex,
              totalItems: kPlaylist.length,
              ahead: _ahead,
            ),
          ),

          const Divider(height: 8),

          // ── Playlist ──────────────────────────────────────────────────────
          Expanded(
            child: ListenableBuilder(
              listenable: _ctrl,
              builder: (_, __) => _PlaylistView(
                ctrl: _ctrl,
                ahead: _ahead,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pre-cache status bar ──────────────────────────────────────────────────────

class _PrecacheStatusBar extends StatelessWidget {
  final int currentIndex;
  final int totalItems;
  final int ahead;

  const _PrecacheStatusBar({
    required this.currentIndex,
    required this.totalItems,
    required this.ahead,
  });

  @override
  Widget build(BuildContext context) {
    final precachedIndices = <int>[
      for (int i = currentIndex + 1;
          i <= (currentIndex + ahead) && i < totalItems;
          i++)
        i
    ];

    if (precachedIndices.isEmpty) return const SizedBox.shrink();

    final labels = precachedIndices
        .map((i) => kPlaylist[i].title)
        .map((t) => t.length > 20 ? '${t.substring(0, 18)}…' : t)
        .join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.download_for_offline,
              size: 14, color: Colors.tealAccent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Pre-caching: $labels',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.tealAccent),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Playlist view ─────────────────────────────────────────────────────────────

class _PlaylistView extends StatelessWidget {
  final ExoPlayerController ctrl;
  final int ahead;

  const _PlaylistView({required this.ctrl, required this.ahead});

  @override
  Widget build(BuildContext context) {
    final current = ctrl.currentMediaItemIndex;

    return ListView.builder(
      itemCount: kPlaylist.length,
      itemBuilder: (context, i) {
        final entry = kPlaylist[i];
        final isCurrent = i == current;
        final isPrecached = i > current && i <= current + ahead;
        final isPast = i < current;

        final (icon, iconColor) = switch (true) {
          true when isCurrent => (Icons.play_arrow, Colors.greenAccent),
          true when isPrecached => (Icons.download_done, Colors.tealAccent),
          true when isPast => (Icons.check_circle_outline, Colors.grey),
          _ => (Icons.hourglass_empty_outlined, Colors.white24),
        };

        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: iconColor.withValues(alpha: 0.12),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          title: Text(
            entry.title,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent ? Colors.white : Colors.white70,
            ),
          ),
          subtitle: Text(
            '${entry.format}'
            '${isPrecached ? '  ·  5 MB pre-cached' : ''}'
            '${isCurrent ? '  ·  now playing' : ''}',
            style: TextStyle(
              fontSize: 11,
              color: isPrecached
                  ? Colors.tealAccent
                  : isCurrent
                      ? Colors.greenAccent
                      : Colors.white38,
            ),
          ),
          onTap: () => ctrl.seekToMediaItem(i, Duration.zero),
        );
      },
    );
  }
}
