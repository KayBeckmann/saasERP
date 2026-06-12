import 'dart:io';

import 'package:postgres/postgres.dart';

import 'config.dart';

/// Erstellt einen Connection-Pool gemäß [AppConfig].
///
/// `sslMode: SslMode.disable`, da Backend und Postgres im selben
/// Docker-Netzwerk laufen (siehe docker-compose.yml).
Pool<void> createDbPool(AppConfig config) {
  return Pool.withEndpoints(
    [
      Endpoint(
        host: config.dbHost,
        port: config.dbPort,
        database: config.dbName,
        username: config.dbUser,
        password: config.dbPassword,
      ),
    ],
    settings: const PoolSettings(
      sslMode: SslMode.disable,
      maxConnectionCount: 5,
    ),
  );
}

/// Führt alle SQL-Dateien aus `migrations/` in alphabetischer Reihenfolge aus.
Future<void> runMigrations(Pool<void> pool) async {
  final migrationsDir = Directory('migrations');
  if (!migrationsDir.existsSync()) return;

  final files = migrationsDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final sql = await file.readAsString();
    await pool.execute(Sql(sql), ignoreRows: true);
  }
}
