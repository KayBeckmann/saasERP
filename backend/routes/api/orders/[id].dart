import 'dart:convert';

import 'package:backend/src/repositories/article_repository.dart';
import 'package:backend/src/repositories/order_repository.dart';
import 'package:backend/src/repositories/product_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/orders/<id> — einzelnen Auftrag lesen.
/// PATCH /api/orders/<id> — Auftrag aktualisieren.
/// DELETE /api/orders/<id> — Auftrag löschen.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final orderRepository = context.read<OrderRepository>();

  if (context.request.method == HttpMethod.get) {
    final order = await orderRepository.findById(tenantId: auth.tenantId, id: id);
    if (order == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: order.toJson());
  }

  if (context.request.method == HttpMethod.patch) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final UpdateOrderRequest req;
    try {
      req = UpdateOrderRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.title.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'title darf nicht leer sein.'},
      );
    }

    final existing = await orderRepository.findById(tenantId: auth.tenantId, id: id);
    if (existing == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }

    final order = await orderRepository.update(tenantId: auth.tenantId, id: id, req: req);
    if (order == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }

    // Lagerentnahme: beim Übergang in den Status "completed" wird der Bedarf
    // aus den Auftragspositionen (inkl. Artikel aus Produkt-Komponenten) vom
    // Lagerbestand abgezogen — analog zur Bedarfsermittlung im Bestellvorschlag.
    if (existing.status != OrderStatus.completed && order.status == OrderStatus.completed) {
      await _consumeStock(context, tenantId: auth.tenantId, order: order);
    }

    return Response.json(body: order.toJson());
  }

  if (context.request.method == HttpMethod.delete) {
    final deleted = await orderRepository.delete(tenantId: auth.tenantId, id: id);
    if (!deleted) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response(statusCode: 204);
  }

  return Response(statusCode: 405);
}

/// Summiert die benötigte Menge je Artikel aus direkten Artikel-Positionen
/// und aus den Artikel-Komponenten verwendeter Produkte und bucht sie als
/// Lagerentnahme (negativer Bestand möglich, signalisiert Überverbrauch).
Future<void> _consumeStock(RequestContext context, {required String tenantId, required Order order}) async {
  final productRepository = context.read<ProductRepository>();
  final articleRepository = context.read<ArticleRepository>();

  final consumedQuantities = <String, double>{};
  for (final item in order.items) {
    if (item.kind == OrderItemKind.article && item.articleId != null) {
      consumedQuantities[item.articleId!] = (consumedQuantities[item.articleId!] ?? 0) + item.quantity;
      continue;
    }
    if (item.kind == OrderItemKind.product && item.productId != null) {
      final product = await productRepository.findById(tenantId: tenantId, id: item.productId!);
      if (product == null) continue;
      for (final component in product.components) {
        if (component.kind == ProductComponentKind.article && component.articleId != null) {
          consumedQuantities[component.articleId!] =
              (consumedQuantities[component.articleId!] ?? 0) + component.quantity * item.quantity;
        }
      }
    }
  }

  for (final entry in consumedQuantities.entries) {
    await articleRepository.adjustStock(tenantId: tenantId, id: entry.key, delta: -entry.value);
  }
}
