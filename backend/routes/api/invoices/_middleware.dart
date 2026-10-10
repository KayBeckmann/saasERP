import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Generic invoice APIs are staff-only. Customer JWTs must use the
/// customer-portal endpoints, which scope invoices to the portal account.
Handler middleware(Handler handler) {
  return (context) async {
    final auth = authenticateRequest(context);
    if (auth == null) {
      return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
    }
    if (auth.role != UserRole.owner.toJson() &&
        auth.role != UserRole.employee.toJson()) {
      return Response.json(statusCode: 403, body: {'error': 'forbidden'});
    }
    return handler(context);
  };
}
