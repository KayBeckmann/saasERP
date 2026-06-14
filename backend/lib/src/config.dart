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
}
