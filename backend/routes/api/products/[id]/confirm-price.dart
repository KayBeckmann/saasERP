import 'package:backend/src/repositories/product_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /api/products/<id>/confirm-price — übernimmt den vorgeschlagenen
/// Verkaufspreis und aktualisiert die Artikel-Positionen auf die aktuellen
/// Einkaufspreise.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final productRepository = context.read<ProductRepository>();
  final product = await productRepository.confirmPendingPrice(tenantId: auth.tenantId, id: id);
  if (product == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }
  return Response.json(body: product.toJson());
}
