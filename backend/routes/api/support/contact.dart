import 'dart:async';
import 'dart:convert';

import 'package:backend/src/notification_service.dart';
import 'package:dart_frog/dart_frog.dart';

/// POST /api/support/contact — öffentlicher Support-Kanal (M5/M6): leitet
/// eine Support-Anfrage per E-Mail an SUPPORT_EMAIL weiter. Kein Auth nötig —
/// zugänglich vor dem Login. Body: {name, email, message, subject?}.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
  } on FormatException {
    return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
  }

  final name = (body['name'] as String?)?.trim() ?? '';
  final email = (body['email'] as String?)?.trim() ?? '';
  final message = (body['message'] as String?)?.trim() ?? '';
  final subject = (body['subject'] as String?)?.trim();

  if (name.isEmpty || email.isEmpty || message.isEmpty) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'validation_failed', 'message': 'name, email und message sind Pflichtfelder.'},
    );
  }

  unawaited(context.read<NotificationService>().forwardSupportRequest(
        name: name,
        email: email,
        message: message,
        subject: subject,
      ));

  return Response.json(body: {'status': 'ok', 'message': 'Ihre Anfrage wurde übermittelt. Wir melden uns bald.'});
}
