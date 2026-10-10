import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';
import 'request_auth.dart';

/// Access is based on a verified owner JWT, never on mail headers.
Response? intakeOwnerGate(RequestContext context) {
  final auth = authenticateRequest(context);
  if (auth == null)
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  if (auth.role != UserRole.owner.toJson())
    return Response.json(statusCode: 403, body: {'error': 'forbidden'});
  return null;
}
