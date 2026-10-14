import 'package:backend/src/pdf/purchase_order_pdf_builder.dart';
import 'package:backend/src/repositories/article_repository.dart';
import 'package:backend/src/repositories/purchase_order_repository.dart';
import 'package:backend/src/repositories/supplier_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/purchase-orders/<id>/pdf — Bestellung als PDF.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = await requirePermission(context, module: PermissionModule.purchaseOrders, action: PermissionAction.export);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;

  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final purchaseOrder = await context
      .read<PurchaseOrderRepository>()
      .findById(tenantId: payload.tenantId, id: id);
  if (purchaseOrder == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final tenant =
      await context.read<TenantRepository>().findById(payload.tenantId);
  if (tenant == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final supplierId = purchaseOrder.supplierId;
  final supplier = supplierId == null
      ? null
      : await context
          .read<SupplierRepository>()
          .findById(tenantId: payload.tenantId, id: supplierId);

  // Lieferanten-Artikelnummern für alle Positionen mit article_id laden.
  final articleIds = purchaseOrder.items
      .map((i) => i.articleId)
      .whereType<String>()
      .toSet();
  final articles = await context
      .read<ArticleRepository>()
      .findByIds(tenantId: payload.tenantId, ids: articleIds);
  final supplierSkus = {
    for (final a in articles) a.id: a.supplierSku,
  };

  final bytes = await buildPurchaseOrderPdf(
    purchaseOrder: purchaseOrder,
    tenant: tenant,
    supplier: supplier,
    supplierSkus: supplierSkus,
  );

  return Response.bytes(
    body: bytes,
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition':
          'inline; filename="${purchaseOrder.purchaseOrderNumber}.pdf"',
    },
  );
}
