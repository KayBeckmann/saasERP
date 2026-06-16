import 'dart:async';

import 'package:backend/src/notification_service.dart';
import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /api/invoices/<id>/dun — erhöht die Mahnstufe einer Rechnung um eine
/// Stufe (1 = Zahlungserinnerung, 2 = 1. Mahnung, 3 = 2. Mahnung) und
/// addiert die zur neuen Stufe passende Mahngebühr aus der
/// Mandanten-Konfiguration.
Future<Response> onRequest(RequestContext context, String id) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final invoiceRepository = context.read<InvoiceRepository>();
  final invoice = await invoiceRepository.findById(tenantId: auth.tenantId, id: id);
  if (invoice == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  if (invoice.dunningLevel >= 3) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'max_dunning_level_reached', 'message': 'Die maximale Mahnstufe ist bereits erreicht.'},
    );
  }

  final tenant = await context.read<TenantRepository>().findById(auth.tenantId);
  if (tenant == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final fee = switch (invoice.dunningLevel + 1) {
    1 => tenant.dunningFeeLevel1,
    2 => tenant.dunningFeeLevel2,
    _ => tenant.dunningFeeLevel3,
  };

  final updated = await invoiceRepository.recordDunning(tenantId: auth.tenantId, id: id, fee: fee);
  if (updated == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  unawaited(context.read<NotificationService>().notifyCustomerDunning(
        tenantId: auth.tenantId,
        invoice: updated,
      ));

  return Response.json(body: updated.toJson());
}
