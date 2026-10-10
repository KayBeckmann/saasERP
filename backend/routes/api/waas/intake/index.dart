import 'dart:convert';
import 'dart:typed_data';
import 'package:backend/src/repositories/waas_intake_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:backend/src/waas_intake_auth.dart';
import 'package:dart_frog/dart_frog.dart';

/// Owner-only manual import. Not a mail-provider webhook. Mail headers, UID and
/// extracted fields are merely claims supplied by the owner, never auth data.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get &&
      context.request.method != HttpMethod.post)
    return Response(statusCode: 405);
  final denied = intakeOwnerGate(context);
  if (denied != null) return denied;
  final auth = authenticateRequest(context)!;
  final repo = context.read<WaasIntakeRepository>();
  if (context.request.method == HttpMethod.get) {
    final rows = await repo.list(tenantId: auth.tenantId);
    return Response.json(
      body: {
        'requests': rows
            .map(
              (row) => row.map(
                (key, value) => MapEntry(
                  key,
                  value is DateTime ? value.toUtc().toIso8601String() : value,
                ),
              ),
            )
            .toList(),
      },
    );
  }
  final bytes = <int>[];
  await for (final chunk in context.request.bytes()) {
    bytes.addAll(chunk);
    if (bytes.length > 10 * 1024 * 1024) return Response(statusCode: 413);
  }
  try {
    final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final raw = Uint8List.fromList(
      base64Decode(data['raw_message_base64'] as String),
    );
    final pdfEncoded = data['pdf_base64'] as String?;
    final pdf = pdfEncoded == null
        ? null
        : Uint8List.fromList(base64Decode(pdfEncoded));
    final id = await repo.importMessage(
      tenantId: auth.tenantId,
      actorId: auth.userId,
      mailbox: data['mailbox'] as String,
      messageKey: data['message_key'] as String,
      rawMessage: raw,
      instruction: data['instruction'] as String? ?? '',
      claimedFrom: data['claimed_from'] as String? ?? '',
      claimedSubject: data['claimed_subject'] as String? ?? '',
      pdf: pdf,
      pdfName: data['pdf_name'] as String?,
    );
    return Response.json(
      statusCode: 201,
      body: {'id': id, 'status': 'pending'},
    );
  } on StateError catch (_) {
    return Response.json(
      statusCode: 409,
      body: {'error': 'message_key_conflict'},
    );
  } on Exception catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'invalid_import'});
  }
}
