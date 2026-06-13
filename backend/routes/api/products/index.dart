import 'dart:convert';

import 'package:backend/src/repositories/product_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/products — Produktliste des aktuellen Mandanten.
/// POST /api/products — neues Produkt anlegen.
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final productRepository = context.read<ProductRepository>();

  if (context.request.method == HttpMethod.get) {
    final products = await productRepository.list(auth.tenantId);
    return Response.json(body: {'products': products.map((p) => p.toJson()).toList()});
  }

  if (context.request.method == HttpMethod.post) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final CreateProductRequest req;
    try {
      req = CreateProductRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.name.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'name darf nicht leer sein.'},
      );
    }

    final product = await productRepository.create(tenantId: auth.tenantId, req: req);
    return Response.json(statusCode: 201, body: product.toJson());
  }

  return Response(statusCode: 405);
}
