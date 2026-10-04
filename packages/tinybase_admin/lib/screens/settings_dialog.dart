import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_bits.dart';
import 'codegen_dialog.dart';
import 'codegen_style_dialog.dart';

/// Snippet pubspec pour une app hors monorepo (Railway = serveur, GitHub = package).
const _kClientPubspecSnippet = '''
dependencies:
  tinybase_client:
    git:
      url: https://github.com/RomainCourcelle/tinybase.git
      path: packages/tinybase_client
      ref: main
''';

/// Réglages : inscriptions, session, providers OAuth (style Supabase), codegen.
class SettingsScreen extends StatefulWidget {
  final ApiClient client;
  const SettingsScreen({super.key, required this.client});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings? _settings;
  bool _loading = true;
  bool _saving = false;
  bool _generatingAuth = false;
  String? _error;

  bool _registrationsOpen = true;
  final _sessionDaysController = TextEditingController();

  final _discordId = TextEditingController();
  final _discordSecret = TextEditingController();
  final _googleId = TextEditingController();
  final _googleSecret = TextEditingController();
  final _microsoftId = TextEditingController();
  final _microsoftSecret = TextEditingController();
  final _appleId = TextEditingController();
  final _appleTeam = TextEditingController();
  final _appleKey = TextEditingController();
  final _applePrivate = TextEditingController();

  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sessionDaysController.dispose();
    for (final c in [
      _discordId,
      _discordSecret,
      _googleId,
      _googleSecret,
      _microsoftId,
      _microsoftSecret,
      _appleId,
      _appleTeam,
      _appleKey,
      _applePrivate,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await widget.client.getSettings();
      setState(() {
        _settings = settings;
        _registrationsOpen = settings.registrationsOpen;
        _sessionDaysController.text = '${settings.refreshTokenTtlDays}';
        _discordId.text = settings.discord.clientId ?? '';
        _googleId.text = settings.google.clientId ?? '';
        _microsoftId.text = settings.microsoft.clientId ?? '';
        _appleId.text = settings.apple.clientId ?? '';
        _appleTeam.text = settings.apple.teamId ?? '';
        _appleKey.text = settings.apple.keyId ?? '';
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _saveRegistrations(bool value) async {
    setState(() => _registrationsOpen = value);
    try {
      final settings = await widget.client.updateSettings(registrationsOpen: value);
      setState(() => _settings = settings);
    } on ApiException catch (e) {
      setState(() {
        _registrationsOpen = !value;
        _error = e.message;
      });
    }
  }

  Future<void> _saveSession() async {
    final days = int.tryParse(_sessionDaysController.text.trim());
    if (days == null) {
      setState(() => _error = 'Durée de session invalide');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final settings = await widget.client.updateSettings(refreshTokenTtlDays: days);
      setState(() {
        _settings = settings;
        _sessionDaysController.text = '${settings.refreshTokenTtlDays}';
        _saving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Durée de session enregistrée')),
        );
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  Future<void> _saveProvider(String id) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      late final AppSettings settings;
      switch (id) {
        case 'discord':
          settings = await widget.client.updateSettings(
            discordClientId: _discordId.text.trim(),
            discordClientSecret: _discordSecret.text.trim().isEmpty ? null : _discordSecret.text.trim(),
          );
          _discordSecret.clear();
        case 'google':
          settings = await widget.client.updateSettings(
            googleClientId: _googleId.text.trim(),
            googleClientSecret: _googleSecret.text.trim().isEmpty ? null : _googleSecret.text.trim(),
          );
          _googleSecret.clear();
        case 'microsoft':
          settings = await widget.client.updateSettings(
            microsoftClientId: _microsoftId.text.trim(),
            microsoftClientSecret: _microsoftSecret.text.trim().isEmpty ? null : _microsoftSecret.text.trim(),
          );
          _microsoftSecret.clear();
        case 'apple':
          settings = await widget.client.updateSettings(
            appleClientId: _appleId.text.trim(),
            appleTeamId: _appleTeam.text.trim(),
            appleKeyId: _appleKey.text.trim(),
            applePrivateKey: _applePrivate.text.trim().isEmpty ? null : _applePrivate.text.trim(),
          );
          _applePrivate.clear();
        default:
          throw StateError('provider inconnu');
      }
      setState(() {
        _settings = settings;
        _saving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$id enregistré')));
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  Future<void> _disableProvider(String id) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final settings = await widget.client.updateSettings(
        disableDiscord: id == 'discord',
        disableGoogle: id == 'google',
        disableMicrosoft: id == 'microsoft',
        disableApple: id == 'apple',
      );
      setState(() {
        _settings = settings;
        _saving = false;
        _expanded.remove(id);
        if (id == 'discord') {
          _discordId.clear();
          _discordSecret.clear();
        }
        if (id == 'google') {
          _googleId.clear();
          _googleSecret.clear();
        }
        if (id == 'microsoft') {
          _microsoftId.clear();
          _microsoftSecret.clear();
        }
        if (id == 'apple') {
          _appleId.clear();
          _appleTeam.clear();
          _appleKey.clear();
          _applePrivate.clear();
        }
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  Future<void> _generateAuthCode() async {
    final style = await showCodegenStyleDialog(context);
    if (style == null || !mounted) return;

    setState(() {
      _generatingAuth = true;
      _error = null;
    });
    try {
      final files = await widget.client.authCodegen(style: style);
      if (!mounted) return;
      setState(() => _generatingAuth = false);
      await showDialog(
        context: context,
        builder: (_) => CodegenDialog(title: 'Authentification ($style)', files: files),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _generatingAuth = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Réglages',
          subtitle: 'Pris en compte immédiatement, sans redémarrage.',
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 12),
                  ],
                  if (_settings != null) ...[
                    _label('Inscriptions'),
                    const SizedBox(height: 8),
                    _panel(
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        title: const Text('Inscriptions ouvertes', style: TextStyle(color: AppColors.text)),
                        subtitle: const Text('Email/mot de passe et OAuth.'),
                        value: _registrationsOpen,
                        onChanged: _saveRegistrations,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _label('Session'),
                    const SizedBox(height: 8),
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Combien de temps un utilisateur reste connecté (refresh token).',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _sessionDaysController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Durée de session (jours)',
                              hintText: '1 – 365',
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _saving ? null : _saveSession,
                            child: const Text('Enregistrer'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    _label('Auth providers'),
                    const SizedBox(height: 8),
                    _providerCard(
                      id: 'discord',
                      title: 'Discord',
                      info: _settings!.discord,
                      help:
                          'Discord Developer Portal → OAuth2.\n'
                          'Redirect URI : <url-serveur>/api/auth/discord/callback\n'
                          'Côté Flutter : Custom Tab + deep link (pas Chrome plein écran).',
                      fields: [
                        _field(_discordId, 'Client ID'),
                        _field(
                          _discordSecret,
                          'Client Secret',
                          obscure: true,
                          hint: _settings!.discord.secretSet ? '•••••• (vide = ne pas changer)' : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _providerCard(
                      id: 'google',
                      title: 'Google',
                      info: _settings!.google,
                      help:
                          'Google Cloud Console → Credentials (OAuth client, type Web pour le secret serveur).\n'
                          'Côté Flutter : package google_sign_in → idToken → '
                          'tb.auth.signInWithIdToken(OAuthProvider.google, idToken: …).\n'
                          'Pas de redirect navigateur.',
                      fields: [
                        _field(_googleId, 'Client ID'),
                        _field(
                          _googleSecret,
                          'Client Secret',
                          obscure: true,
                          hint: _settings!.google.secretSet ? '•••••• (vide = ne pas changer)' : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _providerCard(
                      id: 'apple',
                      title: 'Apple',
                      info: _settings!.apple,
                      help:
                          'Apple Developer → Identifiers (Services ID) + Keys (Sign in with Apple).\n'
                          'Côté Flutter : sign_in_with_apple → identityToken → '
                          'tb.auth.signInWithIdToken(OAuthProvider.apple, idToken: …).',
                      fields: [
                        _field(_appleId, 'Services ID (Client ID)'),
                        _field(_appleTeam, 'Team ID'),
                        _field(_appleKey, 'Key ID'),
                        _field(
                          _applePrivate,
                          'Private Key (.p8)',
                          obscure: true,
                          maxLines: 4,
                          hint: _settings!.apple.privateKeySet ? '•••••• (vide = ne pas changer)' : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _providerCard(
                      id: 'microsoft',
                      title: 'Microsoft',
                      info: _settings!.microsoft,
                      help:
                          'Azure Portal → App registrations → Certificates & secrets.\n'
                          'Redirect URI : <url-serveur>/api/auth/microsoft/callback\n'
                          'Côté Flutter : même flow que Discord (authorizeUrl + deep link).',
                      fields: [
                        _field(_microsoftId, 'Application (client) ID'),
                        _field(
                          _microsoftSecret,
                          'Client Secret',
                          obscure: true,
                          hint: _settings!.microsoft.secretSet ? '•••••• (vide = ne pas changer)' : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _label('Code client'),
                    const SizedBox(height: 8),
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dans le pubspec de ton app Flutter (hors TinyBase) :',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                            decoration: BoxDecoration(
                              color: AppColors.bgElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    _kClientPubspecSnippet,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontFamily: 'monospace',
                                          color: AppColors.accent,
                                          height: 1.45,
                                        ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Copier',
                                  icon: const Icon(Icons.copy, size: 18),
                                  color: AppColors.textMuted,
                                  onPressed: () {
                                    Clipboard.setData(
                                      const ClipboardData(text: _kClientPubspecSnippet),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Dépendance copiée')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Puis baseUrl = l’URL de ton instance Railway. '
                            'Préfère un tag (ex. v0.1.0) plutôt que main en prod.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textFaint,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Génère Auth (Provider ou Riverpod) qui wrap tinybase_client.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: _generatingAuth ? null : _generateAuthCode,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accentMuted,
                              foregroundColor: AppColors.accent,
                            ),
                            icon: _generatingAuth
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.code, size: 18),
                            label: const Text('Générer le code Auth'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textFaint,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: child,
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool obscure = false,
    String? hint,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        obscureText: obscure && maxLines == 1,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, hintText: hint, isDense: true),
      ),
    );
  }

  Widget _providerCard({
    required String id,
    required String title,
    required OAuthProviderInfo info,
    required String help,
    required List<Widget> fields,
  }) {
    final open = _expanded.contains(id) || info.enabled;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.text)),
                    const SizedBox(width: 10),
                    StatusPill(
                      label: info.enabled ? 'activé' : 'désactivé',
                      color: info.enabled ? AppColors.accent : AppColors.textFaint,
                    ),
                  ],
                ),
              ),
              Switch(
                value: open,
                onChanged: (v) {
                  setState(() {
                    if (v) {
                      _expanded.add(id);
                    } else if (info.enabled) {
                      _disableProvider(id);
                    } else {
                      _expanded.remove(id);
                    }
                  });
                },
              ),
            ],
          ),
          if (open) ...[
            const SizedBox(height: 8),
            Text(help, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            ...fields,
            Row(
              children: [
                FilledButton(
                  onPressed: _saving ? null : () => _saveProvider(id),
                  child: const Text('Enregistrer'),
                ),
                if (info.enabled) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _saving ? null : () => _disableProvider(id),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    child: const Text('Désactiver'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
