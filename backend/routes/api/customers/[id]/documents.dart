import 'package:backend/src/repositories/customer_repository.dart';
import 'package:backend/src/repositories/document_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// GET /api/customers/<id>/documents — vom Kunden im Kundenportal
/// hochgeladene Dokumente (Metadaten) für die User-App.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final customer = await context.read<CustomerRepository>().findById(tenantId: auth.tenantId, id: id);
  if (customer == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final documents = await context.read<DocumentRepository>().listForCustomer(
        tenantId: auth.tenantId,
        customerId: id,
      );
  return Response.json(body: {'documents': documents.map((d) => d.toJson()).toList()});
}
