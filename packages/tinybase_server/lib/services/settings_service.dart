import 'package:sqlite_async/sqlite_async.dart';

/// Réglages globaux de l'instance TinyBase — une seule ligne en base
/// (`_settings`, id fixe `'settings'`), éditable à chaud depuis l'admin
/// sans redémarrage (contrairement aux variables d'env, qui restent le
/// filet de secours au premier démarrage — voir Config).
///
/// Le secret Discord n'est JAMAIS renvoyé en clair par l'API : seul
/// [discordSecretSet] dit s'il est configuré. Sa vraie valeur n'est lue
/// que côté serveur, par [SettingsService.getDiscordClientSecret], au
/// moment de l'échange OAuth2.
class AppSettings {
  final bool registrationsOpen;
  final String? discordClientId;
  final bool discordSecretSet;
  final DateTime updated;

  const AppSettings({
    required this.registrationsOpen,
    required this.discordClientId,
    required this.discordSecretSet,
    required this.updated,
  });

  /// Discord est considéré "activé" quand client id ET secret sont tous
  /// les deux configurés — pas de booléen séparé à faire dériver, comme
  /// dans l'admin NexusBase dont c'est inspiré.
  bool get discordEnabled => (discordClientId?.isNotEmpty ?? false) && discordSecretSet;

  factory AppSettings.fromRow(Map<String, dynamic> row) {
    final secret = row['discord_client_secret'] as String?;
    return AppSettings(
      registrationsOpen: (row['registrations_open'] as int) == 1,
      discordClientId: row['discord_client_id'] as String?,
      discordSecretSet: secret != null && secret.isNotEmpty,
      updated: DateTime.parse(row['updated'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'registrationsOpen': registrationsOpen,
        'discordEnabled': discordEnabled,
        'discordClientId': discordClientId,
        'discordSecretSet': discordSecretSet,
        'updated': updated.toIso8601String(),
      };
}

class SettingsService {
  final SqliteDatabase db;
  const SettingsService(this.db);

  Future<AppSettings> get() async {
    final row = await db.get("SELECT * FROM _settings WHERE id = 'settings'");
    return AppSettings.fromRow(row);
  }

  /// Réservé à un usage interne serveur (échange du code OAuth2 avec
  /// Discord) — jamais exposé via l'API admin.
  Future<String?> getDiscordClientSecret() async {
    final row = await db.getOptional("SELECT discord_client_secret FROM _settings WHERE id = 'settings'");
    return row?['discord_client_secret'] as String?;
  }

  /// `null` = ne pas toucher ce champ. Pour [discordClientSecret]
  /// spécifiquement, une chaîne vide compte aussi comme "ne pas
  /// toucher" — il n'est jamais réaffiché en clair, donc un champ laissé
  /// vide dans le formulaire admin ne peut PAS vouloir dire "efface-le"
  /// (voir le hint "laisse vide pour ne pas le changer"). Pour
  /// effacer explicitement la config Discord, utilise [disableDiscord].
  Future<AppSettings> update({
    bool? registrationsOpen,
    String? discordClientId,
    String? discordClientSecret,
    bool disableDiscord = false,
  }) async {
    final sets = <String>['updated = ?'];
    final values = <Object?>[DateTime.now().toUtc().toIso8601String()];

    if (registrationsOpen != null) {
      sets.add('registrations_open = ?');
      values.add(registrationsOpen ? 1 : 0);
    }

    if (disableDiscord) {
      sets.add('discord_client_id = NULL');
      sets.add('discord_client_secret = NULL');
    } else {
      if (discordClientId != null) {
        sets.add('discord_client_id = ?');
        values.add(discordClientId.isEmpty ? null : discordClientId);
      }
      if (discordClientSecret != null && discordClientSecret.isNotEmpty) {
        sets.add('discord_client_secret = ?');
        values.add(discordClientSecret);
      }
    }

    await db.execute("UPDATE _settings SET ${sets.join(', ')} WHERE id = 'settings'", values);
    return get();
  }
}
