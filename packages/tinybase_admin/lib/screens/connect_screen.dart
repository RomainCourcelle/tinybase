import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/connection_provider.dart';
import '../services/instance_branding.dart';
import '../theme/app_colors.dart';

/// En prod (Dockerfile), le serveur TinyBase sert lui-même l'admin : l'origin
/// du navigateur EST l'API. En dev (`flutter run -d chrome`), l'admin est sur
/// un port Flutter distinct → on demande encore l'URL (défaut localhost:8090).
bool get _isSameOriginProd {
  if (!kIsWeb) return false;
  final host = Uri.base.host;
  return host != 'localhost' && host != '127.0.0.1';
}

String _defaultServerUrl() {
  if (_isSameOriginProd) return Uri.base.origin;
  return 'http://localhost:8090';
}

enum _Step { url, setup, login }

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
  bool _bootstrapping = false;
  final String _brandName = instanceDisplayName(serverUrl: _defaultServerUrl());

  @override
  void initState() {
    super.initState();
    if (_isSameOriginProd) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapSameOrigin());
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapSameOrigin() async {
    setState(() => _bootstrapping = true);
    final connection = context.read<ConnectionProvider>();
    final hasAdmin = await connection.checkAdminStatus(_defaultServerUrl());
    if (!mounted) return;
    if (hasAdmin == null) {
      connection.clearError();
      setState(() {
        _bootstrapping = false;
        _step = _Step.url;
      });
      return;
    }
    setState(() {
      _bootstrapping = false;
      _step = hasAdmin ? _Step.login : _Step.setup;
    });
  }

  Future<void> _submitUrl() async {
    if (!_formKey.currentState!.validate()) return;
    final connection = context.read<ConnectionProvider>();
    final hasAdmin = await connection.checkAdminStatus(_urlController.text);
    if (hasAdmin == null) return;
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

    if (_bootstrapping) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          // Atmosphère : dégradé sombre + halo accent (pas un fond plat).
          const Positioned.fill(child: _ConnectBackdrop()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.accentMuted,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
                              ),
                              child: const Icon(Icons.hub_outlined, color: AppColors.accent, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                connection.baseUrl != null ? connection.displayName : _brandName,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Text(
                          _title(),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 22),
                        ),
                        const SizedBox(height: 8),
                        Text(_subtitle(), style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 28),
                        ..._buildFields(),
                        if (connection.errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            connection.errorMessage!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: connection.isConnecting
                              ? null
                              : (_step == _Step.url ? _submitUrl : _submitCredentials),
                          child: connection.isConnecting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(_ctaLabel()),
                        ),
                        if (_step != _Step.url && !_isSameOriginProd) ...[
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
          ),
        ],
      ),
    );
  }

  String _title() {
    switch (_step) {
      case _Step.url:
        return 'Connexion';
      case _Step.setup:
        return 'Créer l\'admin';
      case _Step.login:
        return 'Bon retour';
    }
  }

  String _subtitle() {
    switch (_step) {
      case _Step.url:
        return 'Indique l\'URL de ton instance (en local seulement).';
      case _Step.setup:
        return 'Premier lancement — ce compte gère le schéma et les données.';
      case _Step.login:
        return 'Connecte-toi avec ton compte administrateur.';
    }
  }

  String _ctaLabel() {
    switch (_step) {
      case _Step.url:
        return 'Continuer';
      case _Step.setup:
        return 'Créer le compte';
      case _Step.login:
        return 'Se connecter';
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
        decoration: const InputDecoration(labelText: 'Email'),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _passwordController,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Mot de passe'),
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
          decoration: const InputDecoration(labelText: 'Confirmer le mot de passe'),
          validator: (v) => v != _passwordController.text ? 'Les mots de passe ne correspondent pas' : null,
          onFieldSubmitted: (_) => _submitCredentials(),
        ),
      ],
    ];
  }
}

class _ConnectBackdrop extends StatelessWidget {
  const _ConnectBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B0F0E),
            Color(0xFF0E1612),
            Color(0xFF0A1210),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.18),
                    AppColors.accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -160,
            left: -100,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1A3D2E).withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
