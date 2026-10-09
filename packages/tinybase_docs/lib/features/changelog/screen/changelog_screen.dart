import 'package:flutter/material.dart';
import 'package:tinybase_docs/core/config.dart';
import 'package:url_launcher/url_launcher.dart';

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 64),
          children: [
            Text(
              'Changelog',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Versions TinyBase (monorepo + tinybase_client).',
              style: theme.textTheme.titleMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.tag, size: 18),
                  label: Text('Release v${AppConfig.version}'),
                  onPressed: () => _open(AppConfig.githubReleaseUrl),
                ),
                ActionChip(
                  avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: Text('client ${AppConfig.version} · pub.dev'),
                  onPressed: () => _open(AppConfig.pubDevClientVersionUrl),
                ),
              ],
            ),
            const SizedBox(height: 28),
            for (final e in _entries) ...[
              _Entry(entry: e),
              const SizedBox(height: 22),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangeEntry {
  final String version;
  final String date;
  final List<String> bullets;
  const _ChangeEntry({
    required this.version,
    required this.date,
    required this.bullets,
  });
}

const _entries = <_ChangeEntry>[
  _ChangeEntry(
    version: '0.4.1',
    date: '2026-10',
    bullets: [
      'Session : `restore()` ne déconnecte plus sur 502/429 ; logout seulement sur 400/401/403.',
      'Refresh lock partagé au démarrage ; migration SharedPreferences → Keystore.',
      'SSE UTF-8 multi-octets ; rate-limit IP = dernier hop `X-Forwarded-For`.',
      'SMTP optionnel pour reset password (`SMTP_*` + `PUBLIC_BASE_URL`).',
      'Pages web Play Store : `/delete-account` et `/reset-password`.',
      'CI GitHub Actions (server + client).',
    ],
  ),
  _ChangeEntry(
    version: '0.4.0',
    date: '2026-10',
    bullets: [
      'Suppression de compte (`DELETE /api/auth/me`) : user, sessions, records `owner` et leurs fichiers.',
      'Logout serveur, mot de passe oublié / reset (pas d’email : token seulement si `RETURN_PASSWORD_RESET_TOKEN=true`).',
      'Refresh tokens rotatifs et révocables. Rate-limit login / register / forgot / reset.',
      'Un filtre `||` ne contourne plus une règle owner (WHERE parenthésé).',
      'Client : Keystore / Keychain par défaut sur mobile, `restore()` garde la session hors ligne.',
      'Admin records : colonne Actions en premier, scrollbars visibles.',
    ],
  ),
  _ChangeEntry(
    version: '0.3.2',
    date: '2026-10',
    bullets: [
      'Docs hébergées : lien `documentation` pub.dev vers ce site.',
    ],
  ),
  _ChangeEntry(
    version: '0.3.1',
    date: '2026-10',
    bullets: [
      '`downloadFile` authentifié (Bearer + refresh).',
      'SSE `subscribe()` : reconnect auto avec backoff.',
      'OAuth callback : tokens en fragment `#` (+ fallback query).',
      'Hardening serveur : MIME wildcards, CORS, multipart, SSE delete ACL.',
    ],
  ),
  _ChangeEntry(
    version: '0.3.0',
    date: '2026-10',
    bullets: [
      'Champs fichier : options `max:` / `mime:` par champ + UI admin.',
      'Collection `users` extensible (schéma custom, register fields, PATCH /me).',
      'tinybase_client : `register(..., fields)`, `updateMe`, `TinyBaseUser.fields`.',
      'Site docs Flutter Web (Getting Started + Exemple).',
    ],
  ),
  _ChangeEntry(
    version: '0.2.0',
    date: '2026-10',
    bullets: [
      'Upload fichiers multipart (`FileUpload`) + `fileUrl`.',
      'Realtime SSE : `collection.subscribe()`.',
      'Branding `APP_NAME` / meta publique.',
    ],
  ),
  _ChangeEntry(
    version: '0.1.x',
    date: '2026',
    bullets: [
      'Première publication pub.dev.',
      'Auth email/password + OAuth, JWT refresh.',
      'CRUD collections + codegen admin.',
    ],
  ),
];

class _Entry extends StatelessWidget {
  final _ChangeEntry entry;
  const _Entry({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'v${entry.version}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              entry.date,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final b in entry.bullets)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
                Expanded(child: Text(b, style: theme.textTheme.bodyLarge)),
              ],
            ),
          ),
      ],
    );
  }
}
