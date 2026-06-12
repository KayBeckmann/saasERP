import 'package:backend/src/config.dart';
import 'package:backend/src/db.dart';

/// Führt alle SQL-Dateien aus `migrations/` aus.
/// Wird beim Container-Start vor dem Server ausgeführt (siehe Dockerfile).
Future<void> main() async {
  final config = AppConfig.fromEnvironment();
  final pool = createDbPool(config);
  await runMigrations(pool);
  await pool.close();
  // ignore: avoid_print
  print('Migrations applied.');
}
