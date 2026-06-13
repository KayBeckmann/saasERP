import 'dart:convert';

import 'package:backend/src/repositories/order_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/orders — Auftragsliste des aktuellen Mandanten.
/// POST /api/orders — neuen Auftrag anlegen.
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final orderRepository = context.read<OrderRepository>();

  if (context.request.method == HttpMethod.get) {
    final orders = await orderRepository.list(auth.tenantId);
    return Response.json(body: {'orders': orders.map((o) => o.toJson()).toList()});
  }

  if (context.request.method == HttpMethod.post) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final CreateOrderRequest req;
    try {
      req = CreateOrderRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.title.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'title darf nicht leer sein.'},
      );
    }

    final order = await orderRepository.create(tenantId: auth.tenantId, req: req);
    return Response.json(statusCode: 201, body: order.toJson());
  }

  return Response(statusCode: 405);
}
