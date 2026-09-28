import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// Réglages globaux de l'instance (inscriptions ouvertes, connexion
/// Discord) — même esprit que la page "Réglages" de NexusBase : édité en
/// base, pris en compte tout de suite, pas de redémarrage.
class SettingsDialog extends StatefulWidget {
  final ApiClient client;
  const SettingsDialog({super.key, required this.client});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  AppSettings? _settings;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _registrationsOpen = true;
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
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
        _clientIdController.text = settings.discordClientId ?? '';
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

  Future<void> _saveDiscord() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final settings = await widget.client.updateSettings(
        discordClientId: _clientIdController.text.trim(),
        discordClientSecret: _clientSecretController.text.trim().isEmpty ? null : _clientSecretController.text.trim(),
      );
      setState(() {
        _settings = settings;
        _clientSecretController.clear();
        _saving = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  Future<void> _disableDiscord() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final settings = await widget.client.updateSettings(disableDiscord: true);
      setState(() {
        _settings = settings;
        _clientIdController.clear();
        _clientSecretController.clear();
        _saving = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 560,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Réglages', style: Theme.of(context).textTheme.titleLarge)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    Text(
                      'Pris en compte immédiatement, sans redémarrage.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
                      ),
                    ] else if (_settings != null) ...[
                      _buildRegistrationsCard(),
                      const SizedBox(height: 16),
                      _buildDiscordCard(),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildRegistrationsCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        title: const Text('Inscriptions ouvertes'),
        subtitle: const Text('Autorise la création de nouveaux comptes (email/mot de passe ou Discord).'),
        value: _registrationsOpen,
        onChanged: _saveRegistrations,
      ),
    );
  }

  Widget _buildDiscordCard() {
    final enabled = _settings?.discordEnabled ?? false;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Connexion Discord', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 12),
                Chip(
                  label: Text(enabled ? 'activé' : 'désactivé'),
                  backgroundColor: enabled ? Colors.green.withValues(alpha: 0.15) : null,
                  labelStyle: enabled ? const TextStyle(color: Colors.green) : null,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Depuis ton application dans le Discord Developer Portal (OAuth2). '
              'Redirect URI à déclarer côté Discord : <url-du-serveur>/api/auth/discord/callback.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _clientIdController,
              decoration: const InputDecoration(labelText: 'Client ID', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _clientSecretController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Client Secret',
                hintText: (_settings?.discordSecretSet ?? false) ? '•••••• (laisser vide pour ne pas le changer)' : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: _saving ? null : _saveDiscord,
                  child: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Enregistrer'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _saving ? null : _disableDiscord,
                  style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  child: const Text('Désactiver Discord'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
