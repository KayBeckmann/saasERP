import 'package:backend/src/repositories/product_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// POST /api/products/<id>/reject-price — verwirft den vorgeschlagenen
/// Verkaufspreis ohne weitere Änderungen.
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final auth = await requirePermission(context, module: PermissionModule.products, action: PermissionAction.edit);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;

  final productRepository = context.read<ProductRepository>();
  final product = await productRepository.rejectPendingPrice(tenantId: payload.tenantId, id: id);
  if (product == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }
  return Response.json(body: product.toJson());
}
