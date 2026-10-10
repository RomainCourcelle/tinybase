import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../core/config.dart';
import 'settings_service.dart';

/// Envoi d'emails optionnel (SMTP).
class MailService {
  SmtpServer _server(SmtpConfig smtp) => SmtpServer(
        smtp.host,
        port: smtp.port,
        username: smtp.user,
        password: smtp.password,
        ssl: smtp.ssl,
        // STARTTLS (587) commence en clair puis upgrade — requis par mailer.
        allowInsecure: !smtp.ssl && smtp.port != 465,
      );

  Future<void> sendPasswordReset({
    required String toEmail,
    required String resetLink,
    required SmtpConfig smtp,
  }) async {
    final app = Config.appName ?? 'TinyBase';
    final message = Message()
      ..from = Address(smtp.from, app)
      ..recipients.add(toEmail)
      ..subject = '$app — réinitialisation du mot de passe'
      ..text = 'Tu as demandé une réinitialisation de mot de passe.\n\n'
          'Ouvre ce lien (valable 1 h) :\n$resetLink\n\n'
          'Si tu n\'es pas à l\'origine de cette demande, ignore cet email.'
      ..html = '<p>Tu as demandé une réinitialisation de mot de passe.</p>'
          '<p><a href="$resetLink">Réinitialiser mon mot de passe</a></p>'
          '<p>Lien valable 1 heure. Si tu n\'es pas à l\'origine de cette '
          'demande, ignore cet email.</p>';

    await send(message, _server(smtp));
  }

  Future<void> sendAccountDeletion({
    required String toEmail,
    required String deleteLink,
    required SmtpConfig smtp,
  }) async {
    final app = Config.appName ?? 'TinyBase';
    final message = Message()
      ..from = Address(smtp.from, app)
      ..recipients.add(toEmail)
      ..subject = '$app — confirmation de suppression de compte'
      ..text = 'Tu as demandé la suppression de ton compte $app.\n\n'
          'Confirme via ce lien (valable 1 h) :\n$deleteLink\n\n'
          'Si tu n\'es pas à l\'origine de cette demande, ignore cet email.'
      ..html = '<p>Tu as demandé la suppression de ton compte <strong>$app</strong>.</p>'
          '<p><a href="$deleteLink">Confirmer la suppression</a></p>'
          '<p>Lien valable 1 heure. Si tu n\'es pas à l\'origine de cette '
          'demande, ignore cet email.</p>';

    await send(message, _server(smtp));
  }
}
