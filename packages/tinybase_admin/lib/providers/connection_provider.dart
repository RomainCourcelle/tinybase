import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../services/api_client.dart';
import '../services/instance_branding.dart';

/// État de connexion au serveur TinyBase (URL + session admin email/mot de
/// passe — voir AdminService côté serveur), persisté en local
/// (shared_preferences -> localStorage sur Flutter Web) pour ne pas avoir à
/// se reconnecter à chaque rechargement de page. Remplace le jeton statique
/// `X-Admin-Token` saisi à la main de la V1.
class ConnectionProvider extends ChangeNotifier {
  static const _prefsUrlKey = 'tinybase_admin.server_url';
  static const _prefsTokenKey = 'tinybase_admin.access_token';
  static const _prefsEmailKey = 'tinybase_admin.admin_email';

  String? _baseUrl;
  String? _adminEmail;
  ApiClient? _client;
  String? _configuredAppName;
  bool _isConnecting = false;
  String? _errorMessage;
  bool _restoring = true;

  String? get baseUrl => _baseUrl;
  String? get adminEmail => _adminEmail;
  bool get isConnected => _client != null;
  bool get isConnecting => _isConnecting;
  bool get isRestoring => _restoring;
  String? get errorMessage => _errorMessage;
  ApiClient get client => _client!;

  /// Nom affiché dans l'UI (APP_NAME ou dérivé du domaine).
  String get displayName => instanceDisplayName(
        configuredName: _configuredAppName,
        serverUrl: _baseUrl,
      );

  Future<void> tryRestoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString(_prefsUrlKey);
      final token = prefs.getString(_prefsTokenKey);
      final email = prefs.getString(_prefsEmailKey);
      if (url != null && token != null && email != null) {
        await _connect(url, token, email, persist: false);
      }
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  /// Précharge le branding pour une URL (écran de connexion).
  Future<String> previewDisplayName(String url) async {
    final configured = await _fetchAppName(url.trim());
    return instanceDisplayName(configuredName: configured, serverUrl: url.trim());
  }

  /// Vérifie l'adresse du serveur ET si un compte admin existe déjà dessus
  /// — décide, côté [ConnectScreen], d'afficher le formulaire "créer le
  /// premier compte admin" ou "se connecter".
  Future<bool?> checkAdminStatus(String url) async {
    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final hasAdmin = await AdminAuthClient(baseUrl: url.trim()).hasAdmin();
      _configuredAppName = await _fetchAppName(url.trim());
      _baseUrl = url.trim();
      _isConnecting = false;
      notifyListeners();
      return hasAdmin;
    } on ApiException catch (e) {
      _isConnecting = false;
      _errorMessage = e.message;
      notifyListeners();
      return null;
    }
  }

  /// Crée le tout premier compte admin de l'instance (échoue si un admin
  /// existe déjà — voir AdminService côté serveur).
  Future<bool> setup(String url, String email, String password) async {
    return _authenticate(() => AdminAuthClient(baseUrl: url.trim()).setup(email, password), url);
  }

  Future<bool> login(String url, String email, String password) async {
    return _authenticate(() => AdminAuthClient(baseUrl: url.trim()).login(email, password), url);
  }

  Future<bool> _authenticate(Future<AdminSession> Function() call, String url) async {
    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final session = await call();
      await _connect(url.trim(), session.accessToken, session.email, persist: true);
      return true;
    } on ApiException catch (e) {
      _isConnecting = false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> _connect(String url, String accessToken, String email, {required bool persist}) async {
    final normalized = url.trim();
    _baseUrl = normalized;
    _adminEmail = email;
    _client = ApiClient(baseUrl: normalized, accessToken: accessToken);
    _configuredAppName = await _fetchAppName(normalized);
    _isConnecting = false;
    notifyListeners();

    if (persist) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsUrlKey, normalized);
        await prefs.setString(_prefsTokenKey, accessToken);
        await prefs.setString(_prefsEmailKey, email);
      } catch (_) {
        // Best effort.
      }
    }
  }

  Future<String?> _fetchAppName(String url) async {
    try {
      final normalized = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final response = await http.get(Uri.parse('$normalized/api/meta')).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['appName'] != null) {
        final name = decoded['appName'].toString().trim();
        return name.isEmpty ? null : name;
      }
    } catch (_) {
      // Best effort — fallback domaine.
    }
    return null;
  }

  /// Efface une erreur réseau issue d'une tentative de connexion
  /// silencieuse (voir ConnectScreen._canAutoConnect) — l'utilisateur n'a
  /// rien demandé, ça ne doit pas s'afficher comme un vrai message d'erreur
  /// une fois qu'on retombe sur l'écran URL classique.
  void clearError() {
    _errorMessage = null;
  }

  Future<void> disconnect() async {
    _client = null;
    _baseUrl = null;
    _adminEmail = null;
    _configuredAppName = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsUrlKey);
      await prefs.remove(_prefsTokenKey);
      await prefs.remove(_prefsEmailKey);
    } catch (_) {
      // Best effort.
    }
  }
}
