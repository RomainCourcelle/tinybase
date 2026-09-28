import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';

/// En prod (voir Dockerfile), le serveur TinyBase sert lui-même l'admin en
/// statique (fallback de buildApp()) : l'admin tourne alors TOUJOURS au même
/// origin que l'API elle-même, donc `Uri.base.origin` (l'URL affichée dans
/// la barre d'adresse du navigateur) EST la bonne valeur — pas besoin de la
/// demander. En dev en revanche (`flutter run -d chrome`), l'admin tourne
/// sur le serveur de dev Flutter (port aléatoire), qui n'a AUCUN rapport
/// avec le port du serveur TinyBase (8090 par défaut) : deviner à partir de
/// l'origin serait faux. On distingue les deux cas avec une heuristique
/// simple : le serveur de dev Flutter Web est toujours sur localhost/127.0.0.1,
/// donc dans ce cas précis on garde l'ancien défaut codé en dur plutôt que
/// de deviner.
String _defaultServerUrl() {
  if (!kIsWeb) return 'http://localhost:8090';
  final origin = Uri.base.origin;
  final host = Uri.base.host;
  if (host == 'localhost' || host == '127.0.0.1') return 'http://localhost:8090';
  return origin;
}

enum _Step { url, setup, login }

/// Écran de connexion en 2 temps : d'abord l'URL du serveur (on demande
/// alors `/api/admin/auth/status` pour savoir si un compte admin existe déjà
/// dessus), puis soit "créer le premier compte admin" (`hasAdmin == false`,
/// premier lancement de l'instance) soit "se connecter" (`hasAdmin == true`)
/// — voir ConnectionProvider/AdminService. Remplace le champ "jeton admin"
/// saisi à la main de la V1.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController(text: _defaultServerUrl());
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Step _step = _Step.url;

  @override
  void dispose() {
    _urlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submitUrl() async {
    if (!_formKey.currentState!.validate()) return;
    final connection = context.read<ConnectionProvider>();
    final hasAdmin = await connection.checkAdminStatus(_urlController.text);
    if (hasAdmin == null) return; // erreur déjà affichée via connection.errorMessage
    setState(() => _step = hasAdmin ? _Step.login : _Step.setup);
  }

  Future<void> _submitCredentials() async {
    if (!_formKey.currentState!.validate()) return;
    final connection = context.read<ConnectionProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final ok = _step == _Step.setup
        ? await connection.setup(_urlController.text, email, password)
        : await connection.login(_urlController.text, email, password);
    if (!ok || !mounted) return;
  }

  void _backToUrl() {
    setState(() => _step = _Step.url);
    _passwordController.clear();
    _confirmController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('TinyBase Admin', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(_subtitle(), style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  ..._buildFields(),
                  if (connection.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(connection.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: connection.isConnecting ? null : (_step == _Step.url ? _submitUrl : _submitCredentials),
                    child: connection.isConnecting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_step == _Step.url ? 'Continuer' : (_step == _Step.setup ? 'Créer le compte' : 'Se connecter')),
                  ),
                  if (_step != _Step.url) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: connection.isConnecting ? null : _backToUrl,
                      child: const Text('← Changer de serveur'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    switch (_step) {
      case _Step.url:
        return 'Connecte-toi à ton instance TinyBase pour gérer les collections et les données.';
      case _Step.setup:
        return 'Premier lancement de cette instance : crée le compte administrateur.';
      case _Step.login:
        return 'Connecte-toi avec ton compte administrateur.';
    }
  }

  List<Widget> _buildFields() {
    if (_step == _Step.url) {
      return [
        TextFormField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'URL du serveur',
            hintText: 'http://localhost:8090',
            border: OutlineInputBorder(),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
          onFieldSubmitted: (_) => _submitUrl(),
        ),
      ];
    }

    return [
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _passwordController,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder()),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Requis';
          if (_step == _Step.setup && v.length < 8) return 'Au moins 8 caractères';
          return null;
        },
        onFieldSubmitted: (_) => _step == _Step.login ? _submitCredentials() : null,
      ),
      if (_step == _Step.setup) ...[
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirmController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Confirmer le mot de passe', border: OutlineInputBorder()),
          validator: (v) => v != _passwordController.text ? 'Les mots de passe ne correspondent pas' : null,
          onFieldSubmitted: (_) => _submitCredentials(),
        ),
      ],
    ];
  }
}
