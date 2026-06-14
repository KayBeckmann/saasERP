import 'dart:convert';

import 'package:backend/src/repositories/project_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/projects — Projektliste des aktuellen Mandanten.
/// POST /api/projects — neues Projekt anlegen.
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final projectRepository = context.read<ProjectRepository>();

  if (context.request.method == HttpMethod.get) {
    final projects = await projectRepository.list(auth.tenantId);
    return Response.json(body: {'projects': projects.map((p) => p.toJson()).toList()});
  }

  if (context.request.method == HttpMethod.post) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final CreateProjectRequest req;
    try {
      req = CreateProjectRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.name.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'name darf nicht leer sein.'},
      );
    }

    final project = await projectRepository.create(tenantId: auth.tenantId, req: req);
    return Response.json(statusCode: 201, body: project.toJson());
  }

  return Response(statusCode: 405);
}
