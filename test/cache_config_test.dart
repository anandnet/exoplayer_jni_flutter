import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:exoplayer_jni_flutter/src/cache_config.dart';

void main() {
  group('CacheConfig', () {
    test('default maxBytes is 500 MB', () {
      const cfg = CacheConfig();
      expect(cfg.maxBytes, equals(500 * 1024 * 1024));
    });

    test('cacheDirectory defaults to null', () {
      const cfg = CacheConfig();
      expect(cfg.cacheDirectory, isNull);
    });

    test('CacheConfig.none has maxBytes == 0', () {
      expect(CacheConfig.none.maxBytes, equals(0));
    });

    test('CacheConfig.none has null cacheDirectory', () {
      expect(CacheConfig.none.cacheDirectory, isNull);
    });

    test('custom maxBytes is stored', () {
      const cfg = CacheConfig(maxBytes: 100 * 1024 * 1024);
      expect(cfg.maxBytes, equals(100 * 1024 * 1024));
    });

    test('custom cacheDirectory is stored', () {
      final dir = Directory('/tmp/test_cache');
      final cfg = CacheConfig(cacheDirectory: dir);
      expect(cfg.cacheDirectory, equals(dir));
    });

    test('cache is enabled when maxBytes > 0', () {
      const cfg = CacheConfig(maxBytes: 1);
      expect(cfg.maxBytes > 0, isTrue);
    });

    test('cache is disabled when maxBytes == 0', () {
      expect(CacheConfig.none.maxBytes > 0, isFalse);
    });
  });
}
