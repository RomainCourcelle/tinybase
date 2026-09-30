import 'package:sqlite_async/sqlite_async.dart';

/// Config publique d'un provider OAuth (secrets jamais exposés — seul [secretSet]).
class OAuthProviderPublic {
  final bool enabled;
  final String? clientId;
  final bool secretSet;
  final String? teamId;
  final String? keyId;
  final bool privateKeySet;

  const OAuthProviderPublic({
    required this.enabled,
    this.clientId,
    this.secretSet = false,
    this.teamId,
    this.keyId,
    this.privateKeySet = false,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'clientId': clientId,
        if (teamId != null) 'teamId': teamId,
        if (keyId != null) 'keyId': keyId,
        'secretSet': secretSet,
        if (privateKeySet) 'privateKeySet': privateKeySet,
      };
}

/// Réglages globaux de l'instance TinyBase — une seule ligne `_settings`.
class AppSettings {
  final bool registrationsOpen;
  final OAuthProviderPublic discord;
  final OAuthProviderPublic google;
  final OAuthProviderPublic apple;
  final OAuthProviderPublic microsoft;
  final int accessTokenTtlHours;
  final int refreshTokenTtlDays;
  final DateTime updated;

  const AppSettings({
    required this.registrationsOpen,
    required this.discord,
    required this.google,
    required this.apple,
    required this.microsoft,
    required this.accessTokenTtlHours,
    required this.refreshTokenTtlDays,
    required this.updated,
  });

  bool get discordEnabled => discord.enabled;
  String? get discordClientId => discord.clientId;
  bool get discordSecretSet => discord.secretSet;

  Duration get accessTokenTtl => Duration(hours: accessTokenTtlHours);
  Duration get refreshTokenTtl => Duration(days: refreshTokenTtlDays);

  factory AppSettings.fromRow(Map<String, dynamic> row) {
    String? s(String key) {
      final v = row[key] as String?;
      return (v == null || v.isEmpty) ? null : v;
    }

    bool has(String key) {
      final v = row[key] as String?;
      return v != null && v.isNotEmpty;
    }

    OAuthProviderPublic browser(String idKey, String secretKey) {
      final id = s(idKey);
      final secretOk = has(secretKey);
      return OAuthProviderPublic(
        enabled: (id?.isNotEmpty ?? false) && secretOk,
        clientId: id,
        secretSet: secretOk,
      );
    }

    final appleId = s('apple_client_id');
    final appleKey = has('apple_private_key');
    final apple = OAuthProviderPublic(
      enabled: (appleId?.isNotEmpty ?? false) &&
          has('apple_team_id') &&
          has('apple_key_id') &&
          appleKey,
      clientId: appleId,
      teamId: s('apple_team_id'),
      keyId: s('apple_key_id'),
      secretSet: false,
      privateKeySet: appleKey,
    );

    return AppSettings(
      registrationsOpen: (row['registrations_open'] as int) == 1,
      discord: browser('discord_client_id', 'discord_client_secret'),
      google: browser('google_client_id', 'google_client_secret'),
      microsoft: browser('microsoft_client_id', 'microsoft_client_secret'),
      apple: apple,
      accessTokenTtlHours: (row['auth_access_ttl_hours'] as int?) ?? 2,
      refreshTokenTtlDays: (row['auth_refresh_ttl_days'] as int?) ?? 30,
      updated: DateTime.parse(row['updated'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'registrationsOpen': registrationsOpen,
        'discordEnabled': discord.enabled,
        'discordClientId': discord.clientId,
        'discordSecretSet': discord.secretSet,
        'providers': {
          'discord': discord.toJson(),
          'google': google.toJson(),
          'apple': apple.toJson(),
          'microsoft': microsoft.toJson(),
        },
        'accessTokenTtlHours': accessTokenTtlHours,
        'refreshTokenTtlDays': refreshTokenTtlDays,
        'updated': updated.toIso8601String(),
      };
}

class SettingsException implements Exception {
  final String message;
  SettingsException(this.message);
}

class SettingsService {
  final SqliteDatabase db;
  const SettingsService(this.db);

  Future<AppSettings> get() async {
    final row = await db.get("SELECT * FROM _settings WHERE id = 'settings'");
    return AppSettings.fromRow(row);
  }

  Future<String?> getDiscordClientSecret() async {
    final row = await db.getOptional("SELECT discord_client_secret FROM _settings WHERE id = 'settings'");
    return row?['discord_client_secret'] as String?;
  }

  Future<String?> getGoogleClientSecret() async {
    final row = await db.getOptional("SELECT google_client_secret FROM _settings WHERE id = 'settings'");
    return row?['google_client_secret'] as String?;
  }

  Future<String?> getMicrosoftClientSecret() async {
    final row = await db.getOptional("SELECT microsoft_client_secret FROM _settings WHERE id = 'settings'");
    return row?['microsoft_client_secret'] as String?;
  }

  Future<({String? clientId, String? teamId, String? keyId, String? privateKey})> getAppleCredentials() async {
    final row = await db.getOptional(
      "SELECT apple_client_id, apple_team_id, apple_key_id, apple_private_key FROM _settings WHERE id = 'settings'",
    );
    return (
      clientId: row?['apple_client_id'] as String?,
      teamId: row?['apple_team_id'] as String?,
      keyId: row?['apple_key_id'] as String?,
      privateKey: row?['apple_private_key'] as String?,
    );
  }

  /// Mise à jour partielle. Pour un provider, passer [disableX] clear les credentials.
  /// Secrets : chaîne vide / null = ne pas toucher (sauf disable).
  Future<AppSettings> update({
    bool? registrationsOpen,
    int? accessTokenTtlHours,
    int? refreshTokenTtlDays,
    // Discord
    String? discordClientId,
    String? discordClientSecret,
    bool disableDiscord = false,
    // Google
    String? googleClientId,
    String? googleClientSecret,
    bool disableGoogle = false,
    // Microsoft
    String? microsoftClientId,
    String? microsoftClientSecret,
    bool disableMicrosoft = false,
    // Apple
    String? appleClientId,
    String? appleTeamId,
    String? appleKeyId,
    String? applePrivateKey,
    bool disableApple = false,
  }) async {
    if (accessTokenTtlHours != null && (accessTokenTtlHours < 1 || accessTokenTtlHours > 72)) {
      throw SettingsException('accessTokenTtlHours doit être entre 1 et 72');
    }
    if (refreshTokenTtlDays != null && (refreshTokenTtlDays < 1 || refreshTokenTtlDays > 365)) {
      throw SettingsException('refreshTokenTtlDays doit être entre 1 et 365');
    }

    final sets = <String>['updated = ?'];
    final values = <Object?>[DateTime.now().toUtc().toIso8601String()];

    void setNullable(String col, String? value) {
      sets.add('$col = ?');
      values.add((value == null || value.isEmpty) ? null : value);
    }

    void setSecret(String col, String? value) {
      if (value != null && value.isNotEmpty) {
        sets.add('$col = ?');
        values.add(value);
      }
    }

    void clear(List<String> cols) {
      for (final c in cols) {
        sets.add('$c = NULL');
      }
    }

    if (registrationsOpen != null) {
      sets.add('registrations_open = ?');
      values.add(registrationsOpen ? 1 : 0);
    }
    if (accessTokenTtlHours != null) {
      sets.add('auth_access_ttl_hours = ?');
      values.add(accessTokenTtlHours);
    }
    if (refreshTokenTtlDays != null) {
      sets.add('auth_refresh_ttl_days = ?');
      values.add(refreshTokenTtlDays);
    }

    if (disableDiscord) {
      clear(['discord_client_id', 'discord_client_secret']);
    } else {
      if (discordClientId != null) setNullable('discord_client_id', discordClientId);
      setSecret('discord_client_secret', discordClientSecret);
    }

    if (disableGoogle) {
      clear(['google_client_id', 'google_client_secret']);
    } else {
      if (googleClientId != null) setNullable('google_client_id', googleClientId);
      setSecret('google_client_secret', googleClientSecret);
    }

    if (disableMicrosoft) {
      clear(['microsoft_client_id', 'microsoft_client_secret']);
    } else {
      if (microsoftClientId != null) setNullable('microsoft_client_id', microsoftClientId);
      setSecret('microsoft_client_secret', microsoftClientSecret);
    }

    if (disableApple) {
      clear(['apple_client_id', 'apple_team_id', 'apple_key_id', 'apple_private_key']);
    } else {
      if (appleClientId != null) setNullable('apple_client_id', appleClientId);
      if (appleTeamId != null) setNullable('apple_team_id', appleTeamId);
      if (appleKeyId != null) setNullable('apple_key_id', appleKeyId);
      setSecret('apple_private_key', applePrivateKey);
    }

    await db.execute("UPDATE _settings SET ${sets.join(', ')} WHERE id = 'settings'", values);
    return get();
  }
}
