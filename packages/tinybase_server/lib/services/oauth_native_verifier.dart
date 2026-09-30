import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';

import 'auth_service.dart';

/// Vérification des idTokens natifs Google / Apple.
class OAuthNativeVerifier {
  /// Google tokeninfo — valide signature + expiry côté Google.
  static Future<({String sub, String? email})> verifyGoogleIdToken(
    String idToken, {
    String? audience,
  }) async {
    final response = await http.get(
      Uri.https('oauth2.googleapis.com', '/tokeninfo', {'id_token': idToken}),
    );
    if (response.statusCode != 200) {
      throw AuthException('idToken Google invalide');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (audience != null && audience.isNotEmpty) {
      final aud = json['aud'] as String?;
      if (aud != audience) throw AuthException('aud Google invalide');
    }
    final sub = json['sub'] as String?;
    if (sub == null || sub.isEmpty) throw AuthException('idToken Google sans sub');
    final email = json['email'] as String?;
    final verified = json['email_verified'] == true || json['email_verified'] == 'true';
    return (sub: sub, email: verified ? email : null);
  }

  /// Apple identity token — vérifie la signature via JWKS Apple + iss/aud.
  static Future<({String sub, String? email})> verifyAppleIdToken(
    String idToken, {
    required String clientId,
  }) async {
    try {
      final keyStore = JsonWebKeyStore()
        ..addKeySetUrl(Uri.parse('https://appleid.apple.com/auth/keys'));
      final jwt = await JsonWebToken.decodeAndVerify(idToken, keyStore);

      final claims = jwt.claims;
      if (claims['iss'] != 'https://appleid.apple.com') {
        throw AuthException('iss Apple invalide');
      }
      final aud = claims['aud'];
      final audOk = aud == clientId || (aud is List && aud.contains(clientId));
      if (!audOk) throw AuthException('aud Apple invalide');

      final sub = claims['sub'] as String?;
      if (sub == null || sub.isEmpty) throw AuthException('idToken Apple sans sub');
      return (sub: sub, email: claims['email'] as String?);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('idToken Apple invalide : $e');
    }
  }
}
