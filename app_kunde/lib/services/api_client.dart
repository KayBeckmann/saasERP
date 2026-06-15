import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:saaserp_shared/saaserp_shared.dart';

import '../config.dart';

/// Wird geworfen, wenn das Backend einen Fehlerstatus zurückgibt.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

/// Schlanker HTTP-Client für die saasERP-Backend-API (Kundenportal-Endpunkte).
class ApiClient {
  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<CustomerAuthResponse> login({required String email, required String password}) async {
    final response = await _httpClient.post(
      _uri('/api/customer-auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(CustomerLoginRequest(email: email, password: password).toJson()),
    );
    return CustomerAuthResponse.fromJson(_decode(response));
  }

  /// Vorschau zu einem Einladungslink — vor Passwortvergabe.
  Future<CustomerInvitePreview> getInvitePreview(String inviteToken) async {
    final response = await _httpClient.get(_uri('/api/customer-invites/$inviteToken'));
    return CustomerInvitePreview.fromJson(_decode(response));
  }

  Future<CustomerAuthResponse> acceptInvite({required String inviteToken, required String password}) async {
    final response = await _httpClient.post(
      _uri('/api/customer-invites/$inviteToken/accept'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(AcceptCustomerInviteRequest(password: password).toJson()),
    );
    return CustomerAuthResponse.fromJson(_decode(response));
  }

  /// Übersicht des eingeloggten Endkunden (eigene Angebote, Rechnungen,
  /// Wartungsverträge/Abos).
  Future<CustomerPortalOverview> getOverview(String token) async {
    final response = await _httpClient.get(
      _uri('/api/customer-portal/overview'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return CustomerPortalOverview.fromJson(_decode(response));
  }

  /// Entscheidung des Endkunden zu einem versendeten Angebot (annehmen/
  /// ablehnen, mit optionalem Kommentar).
  Future<Quote> decideQuote({
    required String token,
    required String quoteId,
    required QuoteStatus decision,
    String? comment,
  }) async {
    final response = await _httpClient.patch(
      _uri('/api/customer-portal/quotes/$quoteId/decision'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(CustomerQuoteDecisionRequest(decision: decision, comment: comment).toJson()),
    );
    return Quote.fromJson(_decode(response));
  }

  /// Endkunde kündigt einen aktiven Wartungsvertrag/Abo zum heutigen Datum.
  Future<MaintenanceContract> cancelMaintenanceContract({required String token, required String contractId}) async {
    final response = await _httpClient.patch(
      _uri('/api/customer-portal/maintenance-contracts/$contractId/cancel'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return MaintenanceContract.fromJson(_decode(response));
  }

  /// Eigene Rechnung als PDF.
  Future<Uint8List> getInvoicePdf({required String token, required String invoiceId}) async {
    final response = await _httpClient.get(
      _uri('/api/customer-portal/invoices/$invoiceId/pdf'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode >= 400) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        (json['message'] ?? json['error'] ?? 'unknown_error').toString(),
      );
    }
    return response.bodyBytes;
  }

  /// Eigene Dokumente (Fotos, Pläne, Vollmachten) — Metadaten ohne Inhalt.
  Future<List<DocumentSummary>> listDocuments(String token) async {
    final response = await _httpClient.get(
      _uri('/api/customer-portal/documents'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = _decode(response);
    return (json['documents'] as List)
        .map((e) => DocumentSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Neues Dokument hochladen — [content] wird Base64-kodiert übertragen.
  Future<DocumentSummary> uploadDocument({
    required String token,
    required String filename,
    required String contentType,
    required Uint8List content,
    String? description,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/customer-portal/documents'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(
        CreateDocumentRequest(
          filename: filename,
          contentType: contentType,
          contentBase64: base64Encode(content),
          description: description,
        ).toJson(),
      ),
    );
    return DocumentSummary.fromJson(_decode(response));
  }

  /// Eigenes Dokument herunterladen.
  Future<Uint8List> getDocument({required String token, required String documentId}) async {
    final response = await _httpClient.get(
      _uri('/api/customer-portal/documents/$documentId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode >= 400) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        (json['message'] ?? json['error'] ?? 'unknown_error').toString(),
      );
    }
    return response.bodyBytes;
  }

  /// Eigenes Dokument löschen.
  Future<void> deleteDocument({required String token, required String documentId}) async {
    final response = await _httpClient.delete(
      _uri('/api/customer-portal/documents/$documentId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode >= 400) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        (json['message'] ?? json['error'] ?? 'unknown_error').toString(),
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, (json['message'] ?? json['error'] ?? 'unknown_error').toString());
    }
    return json;
  }
}
