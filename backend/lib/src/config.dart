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
    );
  }

  final String dbHost;
  final int dbPort;
  final String dbName;
  final String dbUser;
  final String dbPassword;
  final String jwtSecret;
  final String corsOrigin;
}
