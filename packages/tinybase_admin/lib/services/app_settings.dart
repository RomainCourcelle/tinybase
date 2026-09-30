/// Réglages globaux de l'instance — voir settings_service.dart côté serveur.
class OAuthProviderInfo {
  final bool enabled;
  final String? clientId;
  final bool secretSet;
  final String? teamId;
  final String? keyId;
  final bool privateKeySet;

  const OAuthProviderInfo({
    required this.enabled,
    this.clientId,
    this.secretSet = false,
    this.teamId,
    this.keyId,
    this.privateKeySet = false,
  });

  factory OAuthProviderInfo.fromJson(Map<String, dynamic> json) => OAuthProviderInfo(
        enabled: json['enabled'] as bool? ?? false,
        clientId: json['clientId'] as String?,
        secretSet: json['secretSet'] as bool? ?? false,
        teamId: json['teamId'] as String?,
        keyId: json['keyId'] as String?,
        privateKeySet: json['privateKeySet'] as bool? ?? false,
      );
}

class AppSettings {
  final bool registrationsOpen;
  final bool discordEnabled;
  final String? discordClientId;
  final bool discordSecretSet;
  final OAuthProviderInfo discord;
  final OAuthProviderInfo google;
  final OAuthProviderInfo apple;
  final OAuthProviderInfo microsoft;
  final int accessTokenTtlHours;
  final int refreshTokenTtlDays;

  const AppSettings({
    required this.registrationsOpen,
    required this.discordEnabled,
    required this.discordClientId,
    required this.discordSecretSet,
    required this.discord,
    required this.google,
    required this.apple,
    required this.microsoft,
    required this.accessTokenTtlHours,
    required this.refreshTokenTtlDays,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final providers = json['providers'] as Map<String, dynamic>? ?? {};
    OAuthProviderInfo p(String key, {bool? fallbackEnabled, String? fallbackId, bool? fallbackSecret}) {
      final raw = providers[key] as Map<String, dynamic>?;
      if (raw != null) return OAuthProviderInfo.fromJson(raw);
      return OAuthProviderInfo(
        enabled: fallbackEnabled ?? false,
        clientId: fallbackId,
        secretSet: fallbackSecret ?? false,
      );
    }

    return AppSettings(
      registrationsOpen: json['registrationsOpen'] as bool,
      discordEnabled: json['discordEnabled'] as bool? ?? false,
      discordClientId: json['discordClientId'] as String?,
      discordSecretSet: json['discordSecretSet'] as bool? ?? false,
      discord: p(
        'discord',
        fallbackEnabled: json['discordEnabled'] as bool?,
        fallbackId: json['discordClientId'] as String?,
        fallbackSecret: json['discordSecretSet'] as bool?,
      ),
      google: p('google'),
      apple: p('apple'),
      microsoft: p('microsoft'),
      accessTokenTtlHours: json['accessTokenTtlHours'] as int? ?? 2,
      refreshTokenTtlDays: json['refreshTokenTtlDays'] as int? ?? 30,
    );
  }
}
