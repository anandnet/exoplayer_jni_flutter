import 'package:flutter/material.dart' hide RepeatMode;

import 'screens/widget_simple_screen.dart';
import 'screens/widget_external_screen.dart';
import 'screens/custom_overlay_screen.dart';
import 'screens/multi_player_screen.dart';
import 'screens/playlist_screen.dart';
import 'screens/precache_screen.dart';
import 'screens/perf_screen.dart';
import 'screens/lifecycle_screen.dart';
import 'screens/error_screen.dart';
import 'screens/audio_screen.dart';

void main() => runApp(const ExoPlayerDemoApp());

class ExoPlayerDemoApp extends StatelessWidget {
  const ExoPlayerDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExoPlayer JNI — Test Suite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ── Home screen ───────────────────────────────────────────────────────────────

class _TestEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;

  const _TestEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.builder,
  });
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final _tests = <_TestEntry>[
    _TestEntry(
      title: 'Widget — Simple',
      subtitle:
          'ExoPlayerWidget with auto internal controller, full UI controls',
      icon: Icons.smart_display,
      color: Colors.deepPurpleAccent,
      builder: (_) => const WidgetSimpleScreen(),
    ),
    _TestEntry(
      title: 'Widget — External Controller',
      subtitle: 'Inject your own ExoPlayerController into ExoPlayerWidget',
      icon: Icons.settings_remote,
      color: Colors.blueAccent,
      builder: (_) => const WidgetExternalScreen(),
    ),
    _TestEntry(
      title: 'Widget — Custom Overlay',
      subtitle: 'Replace built-in controls with a custom overlayBuilder',
      icon: Icons.layers,
      color: Colors.tealAccent,
      builder: (_) => const CustomOverlayScreen(),
    ),
    _TestEntry(
      title: 'Multi-Player Grid (8×)',
      subtitle: '8 simultaneous ExoPlayer instances in a 2×2 scrollable grid',
      icon: Icons.grid_view,
      color: Colors.orangeAccent,
      builder: (_) => const MultiPlayerScreen(),
    ),
    _TestEntry(
      title: 'Playlist Navigation',
      subtitle: 'setPlaylist(), next/prev, shuffle, repeat modes',
      icon: Icons.queue_music,
      color: Colors.pinkAccent,
      builder: (_) => const PlaylistScreen(),
    ),
    _TestEntry(
      title: 'Auto Pre-Cache',
      subtitle:
          'autoPrecache=true pre-downloads next 2 items for instant transitions',
      icon: Icons.download_for_offline,
      color: Colors.tealAccent,
      builder: (_) => const PrecacheScreen(),
    ),
    _TestEntry(
      title: 'Performance & Stress',
      subtitle: 'Frame timing, RSS memory, rapid-seek JNI stress test',
      icon: Icons.analytics,
      color: Colors.greenAccent,
      builder: (_) => const PerfScreen(),
    ),
    _TestEntry(
      title: 'Lifecycle — Navigate Away & Back',
      subtitle: 'Push and pop pages to verify second-visit surface rebind',
      icon: Icons.swap_horiz,
      color: Colors.amberAccent,
      builder: (_) => const LifecycleScreen(),
    ),
    _TestEntry(
      title: 'Error Handling',
      subtitle: 'Invalid URL, error stream, errorBuilder callback',
      icon: Icons.error_outline,
      color: Colors.redAccent,
      builder: (_) => const ErrorScreen(),
    ),
    _TestEntry(
      title: 'Audio Player',
      subtitle: 'Audio-only playlist — no video surface needed',
      icon: Icons.headphones,
      color: Colors.deepPurpleAccent,
      builder: (_) => const AudioScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ExoPlayer JNI — Test Suite'),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: _tests.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 72, endIndent: 16),
        itemBuilder: (context, i) {
          final t = _tests[i];
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: t.color.withValues(alpha: 0.15),
              child: Icon(t.icon, color: t.color, size: 22),
            ),
            title: Text(t.title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(t.subtitle,
                style: const TextStyle(fontSize: 12, height: 1.4)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: t.builder),
            ),
          );
        },
      ),
    );
  }
}
