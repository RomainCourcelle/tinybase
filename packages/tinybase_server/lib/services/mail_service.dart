import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../core/config.dart';

/// Envoi d'emails optionnel (SMTP). No-op si [Config.smtpConfigured] est false.
class MailService {
  Future<void> sendPasswordReset({
    required String toEmail,
    required String resetLink,
  }) async {
    if (!Config.smtpConfigured) return;

    final server = SmtpServer(
      Config.smtpHost!,
      port: Config.smtpPort,
      username: Config.smtpUser,
      password: Config.smtpPassword,
      ssl: Config.smtpSsl,
      allowInsecure: !Config.smtpSsl && Config.smtpPort != 465,
    );

    final app = Config.appName ?? 'TinyBase';
    final message = Message()
      ..from = Address(Config.smtpFrom!, app)
      ..recipients.add(toEmail)
      ..subject = '$app — réinitialisation du mot de passe'
      ..text = 'Tu as demandé une réinitialisation de mot de passe.\n\n'
          'Ouvre ce lien (valable 1 h) :\n$resetLink\n\n'
          'Si tu n\'es pas à l\'origine de cette demande, ignore cet email.'
      ..html = '<p>Tu as demandé une réinitialisation de mot de passe.</p>'
          '<p><a href="$resetLink">Réinitialiser mon mot de passe</a></p>'
          '<p>Lien valable 1 heure. Si tu n\'es pas à l\'origine de cette '
          'demande, ignore cet email.</p>';

    await send(message, server);
  }
}
