import 'package:backend/src/subscription_validation.dart';
import 'dart:convert';

import 'package:backend/src/repositories/order_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/orders — Auftragsliste des aktuellen Mandanten.
/// POST /api/orders — neuen Auftrag anlegen.
Future<Response> onRequest(RequestContext context) async {
  final action = context.request.method == HttpMethod.post
      ? PermissionAction.create
      : PermissionAction.view;
  final auth = await requirePermission(context, module: PermissionModule.orders, action: action);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;

  final orderRepository = context.read<OrderRepository>();

  if (context.request.method == HttpMethod.get) {
    final orders = await orderRepository.list(payload.tenantId);
    return Response.json(
      body: {'orders': orders.map((o) => o.toJson()).toList()},
    );
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
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    try {
      validateSubscription(
        req.isSubscription,
        req.billingInterval,
        req.billingStartDate,
        req.customerId,
      );
    } on ArgumentError {
      return Response.json(
        statusCode: 400,
        body: {
          'error': 'validation_failed',
          'message': 'Abo benötigt Kunde, Intervall und Startdatum.',
        },
      );
    }

    if (req.title.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {
          'error': 'validation_failed',
          'message': 'title darf nicht leer sein.',
        },
      );
    }

    final order = await orderRepository.create(
      tenantId: payload.tenantId,
      req: req,
    );
    return Response.json(statusCode: 201, body: order.toJson());
  }

  return Response(statusCode: 405);
}
