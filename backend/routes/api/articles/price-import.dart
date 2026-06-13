import 'dart:convert';

import 'package:backend/src/repositories/article_repository.dart';
import 'package:backend/src/repositories/product_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// POST /api/articles/price-import — importiert Einkaufspreise aus einer
/// CSV (`sku,einkaufspreis`, Komma oder Semikolon, optionale Kopfzeile wird
/// automatisch erkannt) und aktualisiert Verkaufspreis-Vorschläge für
/// betroffene Produkte.
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  } on FormatException {
    return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
  }

  late final ArticlePriceImportRequest req;
  try {
    req = ArticlePriceImportRequest.fromJson(body);
  } on TypeError {
    return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
  }

  final pricesBySku = <String, double>{};
  for (final line in req.csv.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final parts = trimmed.split(RegExp('[,;]'));
    if (parts.length < 2) continue;

    final sku = parts[0].trim();
    final price = double.tryParse(parts[1].trim().replaceAll(',', '.'));
    if (sku.isEmpty || price == null) continue;

    pricesBySku[sku] = price;
  }

  final articleRepository = context.read<ArticleRepository>();
  final productRepository = context.read<ProductRepository>();

  final updates = await articleRepository.importPurchasePrices(tenantId: auth.tenantId, pricesBySku: pricesBySku);

  final updatedSkus = updates.map((u) => u.sku).toSet();
  final notFoundSkus = pricesBySku.keys.where((sku) => !updatedSkus.contains(sku)).toList();

  final suggestions = await productRepository.recalculatePendingPrices(
    tenantId: auth.tenantId,
    articleIds: updates.map((u) => u.articleId).toSet(),
  );

  final result = ArticlePriceImportResult(
    updatedArticles: updates,
    notFoundSkus: notFoundSkus,
    productSuggestions: suggestions,
  );
  return Response.json(body: result.toJson());
}
