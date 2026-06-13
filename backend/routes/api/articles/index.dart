import 'dart:convert';

import 'package:backend/src/repositories/article_repository.dart';
import 'package:backend/src/request_auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// GET /api/articles — Artikelliste des aktuellen Mandanten.
/// POST /api/articles — neuen Artikel anlegen.
Future<Response> onRequest(RequestContext context) async {
  final auth = authenticateRequest(context);
  if (auth == null) {
    return Response.json(statusCode: 401, body: {'error': 'unauthorized'});
  }

  final articleRepository = context.read<ArticleRepository>();

  if (context.request.method == HttpMethod.get) {
    final articles = await articleRepository.list(auth.tenantId);
    return Response.json(body: {'articles': articles.map((a) => a.toJson()).toList()});
  }

  if (context.request.method == HttpMethod.post) {
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(await context.request.body()) as Map<String, dynamic>;
    } on FormatException {
      return Response.json(statusCode: 400, body: {'error': 'invalid_json'});
    }

    late final CreateArticleRequest req;
    try {
      req = CreateArticleRequest.fromJson(body);
    } on TypeError {
      return Response.json(statusCode: 400, body: {'error': 'invalid_body'});
    }

    if (req.name.trim().isEmpty) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'validation_failed', 'message': 'name darf nicht leer sein.'},
      );
    }

    final article = await articleRepository.create(tenantId: auth.tenantId, req: req);
    return Response.json(statusCode: 201, body: article.toJson());
  }

  return Response(statusCode: 405);
}
