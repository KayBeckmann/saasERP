import 'dart:convert';

import 'package:backend/src/repositories/time_entry_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// PATCH /api/time-entries/<id> — Eintrag aktualisieren.
/// DELETE /api/time-entries/<id> — Eintrag löschen.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final timeEntryRepository = context.read<TimeEntryRepository>();

  if (context.request.method == HttpMethod.patch) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final UpdateTimeEntryRequest req;
    try {
      req = UpdateTimeEntryRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.hours <= 0) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'hours muss größer als 0 sein.'},
      );
    }

    final entry = await timeEntryRepository.update(tenantId: auth.tenantId, id: id, req: req);
    if (entry == null) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response.json(body: entry.toJson());
  }

  if (context.request.method == HttpMethod.delete) {
    final deleted = await timeEntryRepository.delete(tenantId: auth.tenantId, id: id);
    if (!deleted) {
      return Response.json(statusCode: 404, body: {'error': 'not_found'});
    }
    return Response(statusCode: 204);
  }

  return Response(statusCode: 405);
}
