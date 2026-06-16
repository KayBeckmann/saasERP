import 'dart:io';

/// Liest die Backend-Konfiguration aus Umgebungsvariablen
/// (siehe `.env` im Repo-Root / docker-compose.yml).
class AppConfig {
  AppConfig._({
    required this.dbHost,
    required this.dbPort,
    required this.dbName,
    required this.dbUser,
    required this.dbPassword,
    required this.jwtSecret,
    required this.corsOrigin,
    required this.encryptionMasterKey,
    required this.appKundeUrl,
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpUsername,
    required this.smtpPassword,
    required this.smtpFrom,
    required this.smtpUseSsl,
    required this.supportEmail,
  });

  factory AppConfig.fromEnvironment() {
    final env = Platform.environment;
    return AppConfig._(
      dbHost: env['POSTGRES_HOST'] ?? 'localhost',
      dbPort: int.tryParse(env['POSTGRES_PORT'] ?? '') ?? 5432,
      dbName: env['POSTGRES_DB'] ?? 'saaserp',
      dbUser: env['POSTGRES_USER'] ?? 'saaserp',
      dbPassword: env['POSTGRES_PASSWORD'] ?? 'saaserp',
      jwtSecret: env['JWT_SECRET'] ?? 'dev-secret-change-me',
      corsOrigin: env['CORS_ORIGIN'] ?? '*',
      encryptionMasterKey: env['ENCRYPTION_MASTER_KEY'] ?? 'dev-encryption-key-change-me',
      appKundeUrl: env['APP_KUNDE_URL'] ?? 'http://localhost:8082',
      smtpHost: env['SMTP_HOST'] ?? '',
      smtpPort: int.tryParse(env['SMTP_PORT'] ?? '') ?? 587,
      smtpUsername: env['SMTP_USERNAME'] ?? '',
      smtpPassword: env['SMTP_PASSWORD'] ?? '',
      smtpFrom: env['SMTP_FROM'] ?? 'noreply@saaserp.local',
      smtpUseSsl: env['SMTP_USE_SSL'] == 'true',
      supportEmail: env['SUPPORT_EMAIL'] ?? '',
    );
  }

  final String dbHost;
  final int dbPort;
  final String dbName;
  final String dbUser;
  final String dbPassword;
  final String jwtSecret;
  final String corsOrigin;

  /// Globaler Master-Key zum Wrapping der Tenant-Datenschlüssel
  /// (Envelope-Encryption, siehe `TenantEncryptionService`).
  final String encryptionMasterKey;

  /// Basis-URL der Kunden-App (`app_kunde`), für Einladungslinks an
  /// Endkunden (`<appKundeUrl>/invite/<token>`).
  final String appKundeUrl;

  /// SMTP-Host für E-Mail-Benachrichtigungen. Leer = E-Mail-Versand
  /// deaktiviert (z. B. lokale Entwicklung/Tests) — `EmailService` loggt
  /// in diesem Fall nur, ohne tatsächlich zu versenden.
  final String smtpHost;

  /// SMTP-Port, üblicherweise 587 (STARTTLS) oder 465 (SSL).
  final int smtpPort;

  /// SMTP-Benutzername, leer für Server ohne Authentifizierung.
  final String smtpUsername;

  /// SMTP-Passwort, leer für Server ohne Authentifizierung.
  final String smtpPassword;

  /// Absenderadresse für Benachrichtigungs-E-Mails.
  final String smtpFrom;

  /// `true` für direktes SSL/TLS (Port 465), `false` für STARTTLS/Klartext.
  final bool smtpUseSsl;

  /// Ziel-E-Mail-Adresse für Support-Anfragen (`POST /api/support/contact`).
  /// Leer = Anfragen werden nur geloggt (SMTP-Verhalten analog zu smtpHost).
  final String supportEmail;
}
