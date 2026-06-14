import 'dart:convert';

import 'package:backend/src/repositories/project_transaction_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// PATCH /api/projects/<id>/transactions/<transactionId> — Transaktion
/// aktualisieren.
/// DELETE /api/projects/<id>/transactions/<transactionId> — Transaktion
/// löschen.
Future<Response> onRequest(RequestContext context, String id, String transactionId) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final projectTransactionRepository = context.read<ProjectTransactionRepository>();

  if (context.request.method == HttpMethod.patch) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final UpdateProjectTransactionRequest req;
    try {
      req = UpdateProjectTransactionRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.description.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'description darf nicht leer sein.'},
      );
    }

    final transaction = await projectTransactionRepository.update(
      tenantId: auth.tenantId,
      projectId: id,
      id: transactionId,
      req: req,
    );
    if (transaction == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: transaction.toJson());
  }

  if (context.request.method == HttpMethod.delete) {
    final deleted = await projectTransactionRepository.delete(
      tenantId: auth.tenantId,
      projectId: id,
      id: transactionId,
    );
    if (!deleted) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response(statusCode: 204);
  }

  return Response(statusCode: 405);
}
