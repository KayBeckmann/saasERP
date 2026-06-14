import 'dart:convert';

import 'package:backend/src/repositories/project_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/projects/<id> — einzelnes Projekt lesen.
/// PATCH /api/projects/<id> — Projekt aktualisieren.
/// DELETE /api/projects/<id> — Projekt löschen.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final projectRepository = context.read<ProjectRepository>();

  if (context.request.method == HttpMethod.get) {
    final project = await projectRepository.findById(tenantId: auth.tenantId, id: id);
    if (project == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: project.toJson());
  }

  if (context.request.method == HttpMethod.patch) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final UpdateProjectRequest req;
    try {
      req = UpdateProjectRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.name.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'name darf nicht leer sein.'},
      );
    }

    final project = await projectRepository.update(tenantId: auth.tenantId, id: id, req: req);
    if (project == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: project.toJson());
  }

  if (context.request.method == HttpMethod.delete) {
    final deleted = await projectRepository.delete(tenantId: auth.tenantId, id: id);
    if (!deleted) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response(statusCode: 204);
  }

  return Response(statusCode: 405);
}
