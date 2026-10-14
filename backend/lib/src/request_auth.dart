import 'package:dart_frog/dart_frog.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import 'auth_service.dart';
import 'authorization_service.dart';

/// Liest und validiert den `Authorization: Bearer <token>`-Header.
///
/// Gibt `null` zurück, wenn der Header fehlt oder das Token ungültig/
/// abgelaufen ist — der Aufrufer antwortet dann mit 401.
///
/// WICHTIG: `payload.role` ist reine Anzeige-/JWT-Metadaten (zum
/// Ausstellungszeitpunkt eingefroren) und darf **niemals** für
/// Autorisierungsentscheidungen verwendet werden — dafür immer
/// [requirePermission]/[AuthorizationService.loadContext], die live aus der
/// DB lesen (siehe RF2: "Rollenwechsel sofort wirksam").
AuthTokenPayload? authenticateRequest(RequestContext context) {
  final header = context.request.headers['Authorization'];
  if (header == null || !header.startsWith('Bearer ')) return null;

  final token = header.substring('Bearer '.length);
  final authService = context.read<AuthService>();
  try {
    return authService.verifyToken(token);
  } on JWTException {
    return null;
  }
}

/// Ergebnis von [requirePermission]: entweder `denied` (401/403-Response,
/// vom Aufrufer direkt zurückzugeben) oder `payload`+`authz` zur weiteren
/// Verwendung im Handler.
typedef PermissionCheck = ({
  Response? denied,
  AuthTokenPayload? payload,
  AuthorizationContext? authz,
});

/// Authentifiziert die Anfrage und prüft deny-by-default, ob der Nutzer
/// [action] auf [module] im Mandanten seines Tokens ausführen darf (RF2 —
/// "Backend autorisiert vor jeder Entschlüsselung"/jeder Datenoperation).
///
/// Verwendung in einem Route-Handler:
/// ```dart
/// final auth = await requirePermission(context, module: PermissionModule.customers, action: PermissionAction.view);
/// if (auth.denied != null) return auth.denied!;
/// final payload = auth.payload!; // tenantId/userId für die Query
/// ```
Future<PermissionCheck> requirePermission(
  RequestContext context, {
  required String module,
  required String action,
}) async {
  final payload = authenticateRequest(context);
  if (payload == null) {
    return (
      denied: Response.json(statusCode: 401, body: {'error': 'unauthorized'}),
      payload: null,
      authz: null,
    );
  }

  final authzService = context.read<AuthorizationService>();
  final authz = await authzService.loadContext(
    userId: payload.userId,
    tenantId: payload.tenantId,
  );
  if (authz == null || !authz.can(module, action)) {
    return (
      denied: Response.json(statusCode: 403, body: {'error': 'forbidden'}),
      payload: payload,
      authz: authz,
    );
  }

  return (denied: null, payload: payload, authz: authz);
}
