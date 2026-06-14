import 'dart:convert';

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

  Map<String, dynamic> _decode(http.Response response) {
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(response.statusCode, (json['message'] ?? json['error'] ?? 'unknown_error').toString());
    }
    return json;
  }
}
