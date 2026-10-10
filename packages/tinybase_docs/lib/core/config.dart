/// App-wide configuration.
class AppConfig {
  static const String appName = 'TinyBase';
  static const String packageName = 'tinybase_docs';

  /// Docs / monorepo release tag (aligned with tinybase_client).
  static const String version = '0.4.3';

  static const String githubUrl =
      'https://github.com/RomainCourcelle/tinybase';
  static const String githubReleaseUrl =
      'https://github.com/RomainCourcelle/tinybase/releases/tag/v$version';
  static const String pubDevClientUrl =
      'https://pub.dev/packages/tinybase_client';
  static const String pubDevClientVersionUrl =
      'https://pub.dev/packages/tinybase_client/versions/$version';
}
