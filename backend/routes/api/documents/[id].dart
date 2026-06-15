import 'package:backend/src/repositories/document_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/documents/<id> — Dokument herunterladen (User-App,
/// mandantengescoped über `tenant_id`).
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final result = await context.read<DocumentRepository>().findContentById(tenantId: auth.tenantId, id: id);
  if (result == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }
  final (summary, content) = result;
  return Response.bytes(
    body: content,
    headers: {
      'Content-Type': summary.contentType,
      'Content-Disposition': 'attachment; filename="${summary.filename}"',
    },
  );
}
