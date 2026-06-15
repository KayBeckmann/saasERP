import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import 'config.dart';

/// Versendet Benachrichtigungs-E-Mails (neues Angebot, neue Rechnung,
/// Status-Änderung) über SMTP.
///
/// Ist [AppConfig.smtpHost] leer (kein SMTP konfiguriert, z. B. lokale
/// Entwicklung/Tests), wird nicht versendet, sondern nur geloggt — Fehler
/// beim Versand dürfen den auslösenden API-Request nie scheitern lassen.
class EmailService {
  EmailService(this._config);

  final AppConfig _config;

  Future<void> sendMail({required String to, required String subject, required String text}) async {
    if (_config.smtpHost.isEmpty) {
      // ignore: avoid_print
      print('[EmailService] SMTP nicht konfiguriert — E-Mail an $to nicht gesendet: $subject');
      return;
    }

    final smtpServer = SmtpServer(
      _config.smtpHost,
      port: _config.smtpPort,
      username: _config.smtpUsername.isEmpty ? null : _config.smtpUsername,
      password: _config.smtpPassword.isEmpty ? null : _config.smtpPassword,
      ssl: _config.smtpUseSsl,
      allowInsecure: !_config.smtpUseSsl,
    );

    final message = Message()
      ..from = Address(_config.smtpFrom)
      ..recipients.add(to)
      ..subject = subject
      ..text = text;

    try {
      await send(message, smtpServer);
    } catch (error) {
      // ignore: avoid_print
      print('[EmailService] Versand an $to fehlgeschlagen: $error');
    }
  }
}
