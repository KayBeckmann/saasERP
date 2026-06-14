import 'dart:convert';

import 'package:backend/src/repositories/maintenance_contract_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/maintenance-contracts — Liste der Wartungsverträge/Abos des
/// aktuellen Mandanten.
/// POST /api/maintenance-contracts — neuen Wartungsvertrag anlegen.
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final maintenanceContractRepository = context.read<MaintenanceContractRepository>();

  if (context.request.method == HttpMethod.get) {
    final contracts = await maintenanceContractRepository.list(auth.tenantId);
    return Response.json(body: {'maintenance_contracts': contracts.map((c) => c.toJson()).toList()});
  }

  if (context.request.method == HttpMethod.post) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final CreateMaintenanceContractRequest req;
    try {
      req = CreateMaintenanceContractRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.title.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'title darf nicht leer sein.'},
      );
    }
    if (req.termMonths <= 0) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'term_months muss größer als 0 sein.'},
      );
    }

    final contract = await maintenanceContractRepository.create(tenantId: auth.tenantId, req: req);
    return Response.json(statusCode: 201, body: contract.toJson());
  }

  return Response(statusCode: 405);
}
