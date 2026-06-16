import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

/// GET / — erweiterter Health-Check: prüft die DB-Erreichbarkeit und
/// liefert einen Timestamp. Status 200 mit `status: ok` falls DB erreichbar,
/// 503 mit `status: degraded` + Fehlerdetail falls DB nicht antwortet.
Future<Response> onRequest(RequestContext context) async {
  final pool = context.read<Pool<void>>();

  String dbStatus;
  String? dbError;
  try {
    await pool.execute('SELECT 1');
    dbStatus = 'ok';
  } catch (e) {
    dbStatus = 'error';
    dbError = e.toString();
  }

  final healthy = dbStatus == 'ok';
  final body = <String, dynamic>{
    'service': 'saasERP backend',
    'status': healthy ? 'ok' : 'degraded',
    'db': dbStatus,
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    if (dbError != null) 'db_error': dbError,
  };

  return Response.json(statusCode: healthy ? 200 : 503, body: body);
}
