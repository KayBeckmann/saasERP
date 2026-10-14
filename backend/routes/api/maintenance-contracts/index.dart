import 'dart:convert';

import 'package:backend/src/repositories/maintenance_contract_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/maintenance-contracts — Liste der Wartungsverträge/Abos des
/// aktuellen Mandanten.
/// POST /api/maintenance-contracts — neuen Wartungsvertrag anlegen.
Future<Response> onRequest(RequestContext context) async {
  final action = switch (context.request.method) {
    HttpMethod.post => PermissionAction.create,
    _ => PermissionAction.view,
  };
  final auth = await requirePermission(context, module: PermissionModule.maintenanceContracts, action: action);
  if (auth.denied != null) return auth.denied!;
  final payload = auth.payload!;

  final maintenanceContractRepository = context.read<MaintenanceContractRepository>();

  if (context.request.method == HttpMethod.get) {
    final contracts = await maintenanceContractRepository.list(payload.tenantId);
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

    final contract = await maintenanceContractRepository.create(tenantId: payload.tenantId, req: req);
    return Response.json(statusCode: 201, body: contract.toJson());
  }

  return Response(statusCode: 405);
}
