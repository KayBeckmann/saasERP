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

/// Schlanker HTTP-Client für die saasERP-Backend-API.
class ApiClient {
  ApiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<AuthResponse> register({
    required String companyName,
    required String email,
    required String password,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
        RegisterRequest(
          companyName: companyName,
          email: email,
          password: password,
        ).toJson(),
      ),
    );
    return AuthResponse.fromJson(_decode(response));
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(LoginRequest(email: email, password: password).toJson()),
    );
    return AuthResponse.fromJson(_decode(response));
  }

  Future<List<TenantAccess>> meTenants(String token) async {
    final response = await _httpClient.get(
      _uri('/api/me/tenants'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = _decode(response);
    return (json['tenants'] as List)
        .map((e) => TenantAccess.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AuthResponse> switchTenant({
    required String token,
    required String tenantId,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/auth/switch_tenant'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(SwitchTenantRequest(tenantId: tenantId).toJson()),
    );
    return AuthResponse.fromJson(_decode(response));
  }

  Future<({AppUser user, Tenant tenant})> me(String token) async {
    final response = await _httpClient.get(
      _uri('/api/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = _decode(response);
    return (
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      tenant: Tenant.fromJson(json['tenant'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(
        response.statusCode,
        (json['message'] ?? json['error'] ?? 'unknown_error').toString(),
      );
    }
    return json;
  }
}
