/// DRM configuration used by [MediaItemBuilder.setDrmConfig].
///
/// Maps to [MediaItem.DrmConfiguration] on the Java side.
class DrmConfig {
  /// DRM scheme UUID string.
  ///
  /// Common values:
  /// - Widevine  : 'widevine'  or 'edef8ba9-79d6-4ace-a3c8-27dcd51d21ed'
  /// - PlayReady : 'playready' or '9a04f079-9840-4286-ab92-e65be0885f95'
  /// - ClearKey  : 'clearkey'  or 'e2719d58-a985-b3c9-781a-b030af78d30e'
  final String scheme;

  /// URL of the license server.
  final String licenseUrl;

  /// Optional HTTP headers to include in license requests.
  final Map<String, String> licenseRequestHeaders;

  /// Whether to enable multi-session DRM (required for some live streams).
  final bool multiSession;

  /// Force default DRM session for clear content tracks.
  final bool forceDefaultLicenseUri;

  const DrmConfig({
    required this.scheme,
    required this.licenseUrl,
    this.licenseRequestHeaders = const {},
    this.multiSession = false,
    this.forceDefaultLicenseUri = false,
  });

  /// Widevine DRM shortcut.
  factory DrmConfig.widevine({
    required String licenseUrl,
    Map<String, String> headers = const {},
    bool multiSession = false,
  }) =>
      DrmConfig(
        scheme: 'widevine',
        licenseUrl: licenseUrl,
        licenseRequestHeaders: headers,
        multiSession: multiSession,
      );

  /// PlayReady DRM shortcut.
  factory DrmConfig.playReady({
    required String licenseUrl,
    Map<String, String> headers = const {},
  }) =>
      DrmConfig(
        scheme: 'playready',
        licenseUrl: licenseUrl,
        licenseRequestHeaders: headers,
      );

  /// ClearKey DRM shortcut (for testing).
  factory DrmConfig.clearKey({
    required String licenseUrl,
  }) =>
      DrmConfig(
        scheme: 'clearkey',
        licenseUrl: licenseUrl,
      );
}
