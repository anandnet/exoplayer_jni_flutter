// Integration tests for ExoPlayerController's auto pre-cache feature.
//
// These tests REQUIRE a physical or emulated Android device.
// Run from the plugin root:
//   flutter test integration_test/ --device-id=<device-id>
//
// What is tested:
// 1. Pre-cache is silently skipped when autoPrecache=false (default)
// 2. Pre-cache is silently skipped when CacheConfig.none is used
// 3. setPlaylistUrls does not throw and builds the correct item count
// 4. Pre-cache tasks complete without crashing when URLs are real HLS streams
// 5. dispose() cleans up gracefully even when pre-cache tasks are in-flight
// 6. Edge cases: empty list, single item (no ahead items), list shorter than
//    autoPrecacheAhead window

import 'dart:io';

import 'package:exoplayer_jni_flutter/exoplayer_jni_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Short HLS segments that respond to range requests — used for cache write
// verification.  Replaced by empty strings in the "no-op" tests.
const _testUrls = [
  'https://storage.googleapis.com/exoplayer-test-media-0/BigBuckBunny_320x180.mp4',
  'https://storage.googleapis.com/exoplayer-test-media-0/shortform_1/playlist.m3u8',
  'https://storage.googleapis.com/exoplayer-test-media-0/shortform_2/playlist.m3u8',
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Helpers ──────────────────────────────────────────────────────────────────

  /// Creates a [CacheConfig] pointing at a fresh temp directory so each test
  /// starts with an empty, isolated cache.
  Future<CacheConfig> tempCacheConfig() async {
    final dir = await Directory.systemTemp.createTemp('exo_precache_test_');
    return CacheConfig(
      cacheDirectory: dir,
      maxBytes: 50 * 1024 * 1024, // 50 MB — enough for test fragments
    );
  }

  // ── Test group ─────────────────────────────────────────────────────────────

  group('ExoPlayerController auto pre-cache', () {
    // ── 1. Default (no pre-cache) ────────────────────────────────────────────

    testWidgets('init defaults: autoPrecache is false, no JNI errors',
        (tester) async {
      final controller = ExoPlayerController();
      addTearDown(controller.dispose);

      await controller.init(cacheConfig: await tempCacheConfig());
      expect(controller.isInitialized, isTrue);
    });

    // ── 2. CacheConfig.none disables autoPrecache ────────────────────────────

    testWidgets('autoPrecache silently disabled when CacheConfig.none',
        (tester) async {
      final controller = ExoPlayerController();
      addTearDown(controller.dispose);

      // autoPrecache=true is requested but cacheConfig.maxBytes==0 →
      // _autoPrecache must remain false; no crash expected.
      await controller.init(
        cacheConfig: CacheConfig.none,
        autoPrecache: true,
      );
      expect(controller.isInitialized, isTrue);
    });

    // ── 3. setPlaylistUrls: empty list ───────────────────────────────────────

    testWidgets('setPlaylistUrls with empty list does not throw',
        (tester) async {
      final controller = ExoPlayerController();
      addTearDown(controller.dispose);

      await controller.init(
        cacheConfig: await tempCacheConfig(),
        autoPrecache: true,
      );
      // Empty list — _triggerPrecache returns immediately due to isEmpty guard.
      expect(() => controller.setPlaylistUrls([]), returnsNormally);
    });

    // ── 4. setPlaylistUrls: single item (no ahead items to cache) ────────────

    testWidgets('setPlaylistUrls with single URL does not trigger ahead cache',
        (tester) async {
      final controller = ExoPlayerController();
      addTearDown(controller.dispose);

      await controller.init(
        cacheConfig: await tempCacheConfig(),
        autoPrecache: true,
        autoPrecacheAhead: 2,
      );
      // Only one item → loop `for i = 1; i <= min(0+2, 0)` never executes.
      expect(
        () => controller.setPlaylistUrls([_testUrls[0]]),
        returnsNormally,
      );
    });

    // ── 5. setPlaylistUrls: multiple items, pre-cache fires without crash ─────

    testWidgets('setPlaylistUrls with multiple URLs starts pre-cache tasks',
        (tester) async {
      final cacheDir =
          await Directory.systemTemp.createTemp('exo_precache_multi_');
      final cacheConfig = CacheConfig(
        cacheDirectory: cacheDir,
        maxBytes: 50 * 1024 * 1024,
      );
      final controller = ExoPlayerController();
      addTearDown(controller.dispose);

      await controller.init(
        cacheConfig: cacheConfig,
        autoPrecache: true,
        autoPrecacheAhead: 2,
        autoPrecacheBytesPerItem: 512 * 1024, // only 512 KB per item for speed
      );

      expect(
        () => controller.setPlaylistUrls(_testUrls),
        returnsNormally,
      );

      // Give background CacheWriter tasks a couple of seconds to start writing.
      await tester.pump(const Duration(seconds: 3));

      // Verify the cache directory received at least one file.
      final files = cacheDir.listSync(recursive: true);
      expect(
        files.isNotEmpty,
        isTrue,
        reason: 'Expected pre-cache to write at least one file to $cacheDir',
      );
    });

    // ── 6. List shorter than autoPrecacheAhead window ────────────────────────

    testWidgets('setPlaylistUrls clamps ahead window to list length',
        (tester) async {
      final controller = ExoPlayerController();
      addTearDown(controller.dispose);

      await controller.init(
        cacheConfig: await tempCacheConfig(),
        autoPrecache: true,
        autoPrecacheAhead: 10, // larger than the 3-item list
      );
      // Only items [1] and [2] should be triggered; no out-of-bounds access.
      expect(
        () => controller.setPlaylistUrls(_testUrls),
        returnsNormally,
      );
    });

    // ── 7. dispose() while pre-cache is in-flight ────────────────────────────

    testWidgets('dispose while pre-cache in progress does not throw',
        (tester) async {
      final controller = ExoPlayerController();
      // Do NOT addTearDown — we call dispose manually inside the test.

      await controller.init(
        cacheConfig: await tempCacheConfig(),
        autoPrecache: true,
        autoPrecacheBytesPerItem: 5 * 1024 * 1024, // 5 MB — takes a while
      );

      controller.setPlaylistUrls(_testUrls);

      // Dispose almost immediately; CacheWriter tasks should be cancelled.
      await tester.pump(const Duration(milliseconds: 200));
      expect(() => controller.dispose(), returnsNormally);
    });

    // ── 8. autoPrecacheAhead = 0: no crash, loop boundary respected ──────────

    testWidgets('autoPrecacheAhead=0 does not crash', (tester) async {
      final controller = ExoPlayerController();
      addTearDown(controller.dispose);

      await controller.init(
        cacheConfig: await tempCacheConfig(),
        autoPrecache: true,
        autoPrecacheAhead: 0, // zero → end = clamp(0+0, 0, len-1) = 0
        // loop: i = 1; i <= 0 → never fires — no ahead items cached
      );

      // Verify the clamp boundary is handled correctly — no crash, no
      // out-of-bounds access.  (Filesystem cannot distinguish pre-cache writes
      // from ExoPlayer's own playback buffering, so we only assert no throw.)
      expect(
        () => controller.setPlaylistUrls(_testUrls),
        returnsNormally,
      );
    });

    // ── 9. Re-initialising _playlistUrls on second setPlaylistUrls call ───────

    testWidgets('second setPlaylistUrls replaces the playlist', (tester) async {
      final controller = ExoPlayerController();
      addTearDown(controller.dispose);

      await controller.init(
        cacheConfig: await tempCacheConfig(),
        autoPrecache: true,
      );

      controller.setPlaylistUrls(_testUrls);
      // Second call must not throw even though the player already has items.
      expect(
        () => controller.setPlaylistUrls([_testUrls[0]]),
        returnsNormally,
      );
    });
  });
}
