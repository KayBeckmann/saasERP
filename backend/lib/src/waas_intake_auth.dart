import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import 'request_auth.dart';

/// Ergebnis von [intakeOwnerGate]: `denied` (401/403, direkt zurückzugeben)
/// oder `payload` zur Weiterverwendung im Handler.
typedef IntakeGate = ({Response? denied, AuthTokenPayload? payload});

/// Zugriff basiert auf einer verifizierten Admin-Rolle (dem RF2-Nachfolger
/// des früheren festen "owner"-Flags aus RF1), niemals auf Mail-Headern.
///
/// Mail-Intake ist eine sicherheitskritische Quarantäne-Funktion (rohe
/// E-Mail-Bytes, potenziell schädliche Anhänge) und bleibt deshalb bewusst
/// Admin-exklusiv, statt generisch über waas-Modul-Berechtigungen (die z. B.
/// die Buchhaltung-Rolle für normale Rechnungsvorgänge erhält) freigegeben
/// zu werden.
Future<IntakeGate> intakeOwnerGate(
  RequestContext context, {
  required String action,
}) async {
  final result = await requirePermission(
    context,
    module: PermissionModule.waas,
    action: action,
  );
  if (result.denied != null) {
    return (denied: result.denied, payload: null);
  }
  if (!result.authz!.isAdminRole) {
    return (
      denied: Response.json(statusCode: 403, body: {'error': 'forbidden'}),
      payload: null,
    );
  }
  return (denied: null, payload: result.payload);
}
