import 'package:flutter_test/flutter_test.dart';
import 'package:exoplayer_jni_flutter/src/drm_config.dart';

void main() {
  group('DrmConfig', () {
    test('stores scheme, licenseUrl, and defaults', () {
      const cfg =
          DrmConfig(scheme: 'widevine', licenseUrl: 'https://lic.example.com');
      expect(cfg.scheme, equals('widevine'));
      expect(cfg.licenseUrl, equals('https://lic.example.com'));
      expect(cfg.licenseRequestHeaders, isEmpty);
      expect(cfg.multiSession, isFalse);
      expect(cfg.forceDefaultLicenseUri, isFalse);
    });

    test('stores custom headers and flags', () {
      const cfg = DrmConfig(
        scheme: 'widevine',
        licenseUrl: 'https://lic.example.com',
        licenseRequestHeaders: {'Authorization': 'Bearer token'},
        multiSession: true,
        forceDefaultLicenseUri: true,
      );
      expect(
          cfg.licenseRequestHeaders['Authorization'], equals('Bearer token'));
      expect(cfg.multiSession, isTrue);
      expect(cfg.forceDefaultLicenseUri, isTrue);
    });
  });

  group('DrmConfig.widevine factory', () {
    test('sets scheme to widevine', () {
      final cfg = DrmConfig.widevine(licenseUrl: 'https://wv.example.com');
      expect(cfg.scheme, equals('widevine'));
    });

    test('stores licenseUrl', () {
      final cfg = DrmConfig.widevine(licenseUrl: 'https://wv.example.com');
      expect(cfg.licenseUrl, equals('https://wv.example.com'));
    });

    test('accepts headers', () {
      final cfg = DrmConfig.widevine(
        licenseUrl: 'https://wv.example.com',
        headers: {'X-Custom': 'value'},
      );
      expect(cfg.licenseRequestHeaders['X-Custom'], equals('value'));
    });

    test('multiSession defaults to false', () {
      final cfg = DrmConfig.widevine(licenseUrl: 'https://wv.example.com');
      expect(cfg.multiSession, isFalse);
    });

    test('multiSession can be enabled', () {
      final cfg = DrmConfig.widevine(
        licenseUrl: 'https://wv.example.com',
        multiSession: true,
      );
      expect(cfg.multiSession, isTrue);
    });
  });

  group('DrmConfig.playReady factory', () {
    test('sets scheme to playready', () {
      final cfg = DrmConfig.playReady(licenseUrl: 'https://pr.example.com');
      expect(cfg.scheme, equals('playready'));
    });

    test('stores licenseUrl', () {
      final cfg = DrmConfig.playReady(licenseUrl: 'https://pr.example.com');
      expect(cfg.licenseUrl, equals('https://pr.example.com'));
    });

    test('accepts headers', () {
      final cfg = DrmConfig.playReady(
        licenseUrl: 'https://pr.example.com',
        headers: {'Authorization': 'token'},
      );
      expect(cfg.licenseRequestHeaders['Authorization'], equals('token'));
    });
  });

  group('DrmConfig.clearKey factory', () {
    test('sets scheme to clearkey', () {
      final cfg = DrmConfig.clearKey(licenseUrl: 'https://ck.example.com');
      expect(cfg.scheme, equals('clearkey'));
    });

    test('stores licenseUrl', () {
      final cfg = DrmConfig.clearKey(licenseUrl: 'https://ck.example.com');
      expect(cfg.licenseUrl, equals('https://ck.example.com'));
    });
  });
}
