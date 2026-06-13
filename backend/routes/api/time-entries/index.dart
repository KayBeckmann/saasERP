import 'dart:convert';

import 'package:backend/src/repositories/time_entry_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/time-entries?from=YYYY-MM-DD&to=YYYY-MM-DD — Stundenerfassung
/// des angemeldeten Nutzers, optional auf einen Zeitraum eingeschränkt
/// (für die Wochenansicht).
/// POST /api/time-entries — neuen Eintrag anlegen.
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final timeEntryRepository = context.read<TimeEntryRepository>();

  if (context.request.method == HttpMethod.get) {
    final query = context.request.uri.queryParameters;
    final from = query['from'] != null ? DateTime.parse(query['from']!) : null;
    final to = query['to'] != null ? DateTime.parse(query['to']!) : null;

    final entries = await timeEntryRepository.list(
      tenantId: auth.tenantId,
      userId: auth.userId,
      from: from,
      to: to,
    );
    return Response.json(body: {'time_entries': entries.map((e) => e.toJson()).toList()});
  }

  if (context.request.method == HttpMethod.post) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final CreateTimeEntryRequest req;
    try {
      req = CreateTimeEntryRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.hours <= 0) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'hours muss größer als 0 sein.'},
      );
    }

    final entry = await timeEntryRepository.create(
      tenantId: auth.tenantId,
      userId: auth.userId,
      req: req,
    );
    return Response.json(statusCode: 201, body: entry.toJson());
  }

  return Response(statusCode: 405);
}
