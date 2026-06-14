import 'dart:convert';

import 'package:backend/src/repositories/project_repository.dart';
import 'package:backend/src/repositories/project_transaction_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/projects/<id>/transactions — sonstige Einnahmen/Ausgaben des
/// Projekts.
/// POST /api/projects/<id>/transactions — neue Projekt-Transaktion anlegen.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final projectRepository = context.read<ProjectRepository>();
  final project = await projectRepository.findById(tenantId: auth.tenantId, id: id);
  if (project == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final projectTransactionRepository = context.read<ProjectTransactionRepository>();

  if (context.request.method == HttpMethod.get) {
    final transactions = await projectTransactionRepository.list(tenantId: auth.tenantId, projectId: id);
    return Response.json(body: {'project_transactions': transactions.map((t) => t.toJson()).toList()});
  }

  if (context.request.method == HttpMethod.post) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final CreateProjectTransactionRequest req;
    try {
      req = CreateProjectTransactionRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.description.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'description darf nicht leer sein.'},
      );
    }

    final transaction = await projectTransactionRepository.create(
      tenantId: auth.tenantId,
      projectId: id,
      req: req,
    );
    return Response.json(statusCode: 201, body: transaction.toJson());
  }

  return Response(statusCode: 405);
}
