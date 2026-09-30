import 'codegen_service.dart';

/// Génère un AuthProvider thin autour de [TinyBaseClient].
///
/// Dépendances pubspec : `tinybase_client` (path), `provider`.
class AuthCodegenService {
  static List<GeneratedFile> generate({
    bool includeDiscord = false,
    bool includeGoogle = false,
    bool includeApple = false,
    bool includeMicrosoft = false,
  }) {
    return [
      GeneratedFile(
        path: 'lib/providers/auth_provider.dart',
        content: _authProvider(
          includeDiscord: includeDiscord,
          includeGoogle: includeGoogle,
          includeApple: includeApple,
          includeMicrosoft: includeMicrosoft,
        ),
      ),
    ];
  }

  static String _authProvider({
    required bool includeDiscord,
    required bool includeGoogle,
    required bool includeApple,
    required bool includeMicrosoft,
  }) {
    final browserBits = <String>[];
    if (includeDiscord) {
      browserBits.add('''
  Uri discordAuthorizeUrl(String target) =>
      client.auth.authorizeUrl(OAuthProvider.discord, target: target);
''');
    }
    if (includeMicrosoft) {
      browserBits.add('''
  Uri microsoftAuthorizeUrl(String target) =>
      client.auth.authorizeUrl(OAuthProvider.microsoft, target: target);
''');
    }
    final nativeBits = <String>[];
    if (includeGoogle) {
      nativeBits.add('''
  /// Après `google_sign_in` : passe l'`idToken` obtenu.
  Future<bool> signInWithGoogleIdToken(String idToken) =>
      _run(() => client.auth.signInWithIdToken(OAuthProvider.google, idToken: idToken));
''');
    }
    if (includeApple) {
      nativeBits.add('''
  /// Après `sign_in_with_apple` : passe l'`identityToken`.
  Future<bool> signInWithAppleIdToken(String idToken) =>
      _run(() => client.auth.signInWithIdToken(OAuthProvider.apple, idToken: idToken));
''');
    }

    final hasBrowser = includeDiscord || includeMicrosoft;

    return '''
// GÉNÉRÉ par TinyBase codegen — ne pas éditer à la main.
// Régénère depuis l'admin TinyBase (Réglages → Code client).
//
// pubspec.yaml :
//   tinybase_client:
//     path: ../tinybase_client   # ou dépendance pub quand publié
//   provider: ^6.1.2
import 'package:flutter/foundation.dart';
import 'package:tinybase_client/tinybase_client.dart';

/// Session utilisateur — wrap [TinyBaseClient.auth] (refresh JWT auto inclus).
class AuthProvider extends ChangeNotifier {
  final TinyBaseClient client;
  AuthProvider(this.client);

  TinyBaseUser? get user => client.auth.user;
  String? get accessToken => client.auth.accessToken;
  bool get isAuthenticated => client.auth.isAuthenticated;

  bool _isRestoring = true;
  String? _errorMessage;

  bool get isRestoring => _isRestoring;
  String? get errorMessage => _errorMessage;

  Future<void> tryRestoreSession() async {
    await client.auth.restore();
    _isRestoring = false;
    notifyListeners();
  }

  Future<bool> register({required String email, required String password}) =>
      _run(() => client.auth.register(email: email, password: password));

  Future<bool> login({required String email, required String password}) =>
      _run(() => client.auth.login(email: email, password: password));
${browserBits.join()}${hasBrowser ? '''
  Future<bool> handleOAuthCallback(Uri callbackUri) async {
    _errorMessage = null;
    try {
      final session = await client.auth.handleOAuthCallback(callbackUri);
      notifyListeners();
      return session != null;
    } on TinyBaseException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }
''' : ''}${nativeBits.join()}
  Future<void> logout() async {
    await client.auth.logout();
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() call) async {
    _errorMessage = null;
    try {
      await call();
      notifyListeners();
      return true;
    } on TinyBaseException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }
}
''';
  }
}
