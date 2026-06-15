import 'dart:convert';
import 'dart:typed_data';

import 'package:backend/src/repositories/customer_portal_account_repository.dart';
import 'package:backend/src/repositories/document_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/customer-portal/documents — eigene Dokumente des Endkunden
/// (Metadaten, ohne Dateiinhalt).
/// POST /api/customer-portal/documents — neues Dokument hochladen (Foto,
/// Plan, Vollmacht — Inhalt als Base64 im Request-Body).
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null || auth.role != 'customer') {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final portalAccountRepository = context.read<CustomerPortalAccountRepository>();
  final account = await portalAccountRepository.findById(auth.userId);
  if (account == null) {
    return Response.json(statusCode: 404, body: {'error': 'not_found'});
  }

  final documentRepository = context.read<DocumentRepository>();

  if (context.request.method == HttpMethod.get) {
    final documents = await documentRepository.listForCustomer(
      tenantId: auth.tenantId,
      customerId: account.customerId,
    );
    return Response.json(body: {'documents': documents.map((d) => d.toJson()).toList()});
  }

  if (context.request.method == HttpMethod.post) {
    final rawBody = await context.request.body();
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(rawBody) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final CreateDocumentRequest req;
    try {
      req = CreateDocumentRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.filename.trim().isEmpty) {
      return Response.json(statusCode: 400, body: {'error': 'validation_failed', 'message': 'filename fehlt'});
    }

    final List<int> content;
    try {
      content = base64Decode(req.contentBase64);
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_content'});
    }
    if (content.isEmpty) {
      return Response.json(statusCode: 400, body: {'error': 'validation_failed', 'message': 'Datei ist leer'});
    }

    final document = await documentRepository.create(
      tenantId: auth.tenantId,
      customerId: account.customerId,
      filename: req.filename.trim(),
      contentType: req.contentType.trim().isEmpty ? 'application/octet-stream' : req.contentType.trim(),
      content: Uint8List.fromList(content),
      description: req.description,
    );
    return Response.json(statusCode: 201, body: document.toJson());
  }

  return Response(statusCode: 405);
}
