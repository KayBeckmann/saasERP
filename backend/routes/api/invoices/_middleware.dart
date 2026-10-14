import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Generic invoice APIs are staff-only. Customer JWTs must use the
/// customer-portal endpoints, which scope invoices to the portal account.
/// `auth.role` ist seit RF2 der freie Rollenname (z. B. "Admin",
/// "Buchhaltung") statt eines festen owner/employee-Enums — nur
/// Kundenportal-Tokens tragen hier den festen Wert `'customer'` (siehe
/// customer-auth/login.dart), daher negativ statt per Allowlist prüfen.
/// Die eigentliche modul-/aktionsbezogene Autorisierung passiert pro Route
/// über `requirePermission`.
Handler middleware(Handler handler) {
  return (context) async {
    final auth = authenticateRequest(context);
    if (auth == null) {
      return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
    }
    if (auth.role == 'customer') {
      return Response.json(statusCode: 403, body: {'error': 'forbidden'});
    }
    return handler(context);
  };
}
