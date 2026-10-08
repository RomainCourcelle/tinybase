import 'codegen_service.dart';
import 'state_management_style.dart';

/// Génère la couche Auth autour de [TinyBaseClient].
///
/// - [StateManagementStyle.provider] → `ChangeNotifier` + `provider`
/// - [StateManagementStyle.riverpod] → `@riverpod` (+ `tinyBaseClientProvider`)
class AuthCodegenService {
  static List<GeneratedFile> generate({
    bool includeDiscord = false,
    bool includeGoogle = false,
    bool includeApple = false,
    bool includeMicrosoft = false,
    StateManagementStyle style = StateManagementStyle.provider,
  }) {
    final content = switch (style) {
      StateManagementStyle.provider => _authProvider(
          includeDiscord: includeDiscord,
          includeGoogle: includeGoogle,
          includeApple: includeApple,
          includeMicrosoft: includeMicrosoft,
        ),
      StateManagementStyle.riverpod => _authRiverpod(
          includeDiscord: includeDiscord,
          includeGoogle: includeGoogle,
          includeApple: includeApple,
          includeMicrosoft: includeMicrosoft,
        ),
    };
    return [
      GeneratedFile(path: 'lib/providers/auth_provider.dart', content: content),
    ];
  }

  static String _oauthHelpers({
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
    final oauthCallback = hasBrowser
        ? '''
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
'''
        : '';
    return '${browserBits.join()}$oauthCallback${nativeBits.join()}';
  }

  static String _authProvider({
    required bool includeDiscord,
    required bool includeGoogle,
    required bool includeApple,
    required bool includeMicrosoft,
  }) {
    final oauth = _oauthHelpers(
      includeDiscord: includeDiscord,
      includeGoogle: includeGoogle,
      includeApple: includeApple,
      includeMicrosoft: includeMicrosoft,
    );

    return '''
// GÉNÉRÉ par TinyBase codegen — ne pas éditer à la main.
// Régénère depuis l'admin TinyBase (Réglages → Code client).
//
// pubspec.yaml :
//   tinybase_client: ...
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

  Future<bool> register({
    required String email,
    required String password,
    Map<String, dynamic> fields = const {},
  }) =>
      _run(() => client.auth.register(email: email, password: password, fields: fields));

  Future<bool> login({required String email, required String password}) =>
      _run(() => client.auth.login(email: email, password: password));

  Future<bool> updateMe(Map<String, dynamic> fields) =>
      _run(() => client.auth.updateMe(fields));
$oauth
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

  static String _oauthHelpersRiverpod({
    required bool includeDiscord,
    required bool includeGoogle,
    required bool includeApple,
    required bool includeMicrosoft,
  }) {
    final bits = <String>[];
    if (includeDiscord) {
      bits.add('''
  Uri discordAuthorizeUrl(String target) =>
      _client.auth.authorizeUrl(OAuthProvider.discord, target: target);
''');
    }
    if (includeMicrosoft) {
      bits.add('''
  Uri microsoftAuthorizeUrl(String target) =>
      _client.auth.authorizeUrl(OAuthProvider.microsoft, target: target);
''');
    }
    if (includeDiscord || includeMicrosoft) {
      bits.add('''
  Future<bool> handleOAuthCallback(Uri callbackUri) async {
    state = state.copyWith(clearError: true);
    try {
      final session = await _client.auth.handleOAuthCallback(callbackUri);
      state = state.copyWith();
      return session != null;
    } on TinyBaseException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }
''');
    }
    if (includeGoogle) {
      bits.add('''
  /// Après `google_sign_in` : passe l'`idToken` obtenu.
  Future<bool> signInWithGoogleIdToken(String idToken) =>
      _run(() => _client.auth.signInWithIdToken(OAuthProvider.google, idToken: idToken));
''');
    }
    if (includeApple) {
      bits.add('''
  /// Après `sign_in_with_apple` : passe l'`identityToken`.
  Future<bool> signInWithAppleIdToken(String idToken) =>
      _run(() => _client.auth.signInWithIdToken(OAuthProvider.apple, idToken: idToken));
''');
    }
    return bits.join();
  }

  static String _authRiverpod({
    required bool includeDiscord,
    required bool includeGoogle,
    required bool includeApple,
    required bool includeMicrosoft,
  }) {
    final oauth = _oauthHelpersRiverpod(
      includeDiscord: includeDiscord,
      includeGoogle: includeGoogle,
      includeApple: includeApple,
      includeMicrosoft: includeMicrosoft,
    );

    return '''
// GÉNÉRÉ par TinyBase codegen — ne pas éditer à la main.
// Régénère depuis l'admin TinyBase (Réglages → Code client).
//
// Dépendances (sans versions — Pub résout le dernier compatible) :
//   flutter pub add flutter_riverpod riverpod_annotation tinybase_client
//   flutter pub add dev:build_runner dev:riverpod_generator
//
// Puis : dart run build_runner build
//
// Au démarrage :
//   final client = TinyBaseClient(baseUrl: 'https://...');
//   final container = ProviderContainer(
//     overrides: [
//       tinyBaseClientProvider.overrideWithValue(client),
//     ],
//   );
//   await container.read(authProvider.notifier).tryRestoreSession();
//   runApp(
//     UncontrolledProviderScope(
//       container: container,
//       child: MyApp(),
//     ),
//   );
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tinybase_client/tinybase_client.dart';

part 'auth_provider.g.dart';

/// Client TinyBase — à overrider au démarrage (voir en-tête).
@Riverpod(keepAlive: true)
TinyBaseClient tinyBaseClient(Ref ref) {
  throw UnimplementedError(
    'Override tinyBaseClientProvider '
    '(tinyBaseClientProvider.overrideWithValue(...)).',
  );
}

/// Session utilisateur — wrap [TinyBaseClient.auth] (refresh JWT auto inclus).
@Riverpod(keepAlive: true)
class Auth extends _\$Auth {
  TinyBaseClient get _client => ref.read(tinyBaseClientProvider);

  TinyBaseUser? get user => _client.auth.user;
  String? get accessToken => _client.auth.accessToken;
  bool get isAuthenticated => _client.auth.isAuthenticated;

  @override
  AuthUiState build() => const AuthUiState(isRestoring: true);

  Future<void> tryRestoreSession() async {
    await _client.auth.restore();
    state = state.copyWith(isRestoring: false);
  }

  Future<bool> register({
    required String email,
    required String password,
    Map<String, dynamic> fields = const {},
  }) =>
      _run(() => _client.auth.register(email: email, password: password, fields: fields));

  Future<bool> login({required String email, required String password}) =>
      _run(() => _client.auth.login(email: email, password: password));

  Future<bool> updateMe(Map<String, dynamic> fields) =>
      _run(() => _client.auth.updateMe(fields));
$oauth
  Future<void> logout() async {
    await _client.auth.logout();
    state = state.copyWith(clearError: true);
  }

  Future<bool> _run(Future<void> Function() call) async {
    state = state.copyWith(clearError: true);
    try {
      await call();
      // Force un rebuild pour exposer user / isAuthenticated à jour.
      state = state.copyWith();
      return true;
    } on TinyBaseException catch (e) {
      state = state.copyWith(errorMessage: e.message);
      return false;
    }
  }
}

class AuthUiState {
  final bool isRestoring;
  final String? errorMessage;

  const AuthUiState({this.isRestoring = false, this.errorMessage});

  AuthUiState copyWith({
    bool? isRestoring,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthUiState(
      isRestoring: isRestoring ?? this.isRestoring,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
''';
  }
}
