import 'package:backend/src/repositories/customer_portal_account_repository.dart';
import 'package:backend/src/repositories/document_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/customer-portal/documents/<id> — eigenes Dokument herunterladen.
/// DELETE /api/customer-portal/documents/<id> — eigenes Dokument löschen.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null || auth.role != 'customer') {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final portalAccountRepository = context.read<CustomerPortalAccountRepository>();
  final account = await portalAccountRepository.findById(auth.userId);
  if (account == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final documentRepository = context.read<DocumentRepository>();

  if (context.request.method == HttpMethod.get) {
    final result = await documentRepository.findContentById(tenantId: auth.tenantId, id: id);
    if (result == null || result.$1.customerId != account.customerId) {
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

  if (context.request.method == HttpMethod.delete) {
    final summary = await documentRepository.findSummaryById(tenantId: auth.tenantId, id: id);
    if (summary == null || summary.customerId != account.customerId) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    final deleted = await documentRepository.delete(
      tenantId: auth.tenantId,
      id: id,
      customerId: account.customerId,
    );
    if (!deleted) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response(statusCode: 204);
  }

  return Response(statusCode: 405);
}
