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

  Future<Tenant> updateTenantBranding({
    required String token,
    required String? brandingColor,
  }) async {
    final response = await _httpClient.patch(
      _uri('/api/tenant/branding'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(
        UpdateTenantBrandingRequest(brandingColor: brandingColor).toJson(),
      ),
    );
    return Tenant.fromJson(_decode(response));
  }

  Future<Tenant> updateTenantConfig({
    required String token,
    required UpdateTenantConfigRequest config,
  }) async {
    final response = await _httpClient.patch(
      _uri('/api/tenant/config'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(config.toJson()),
    );
    return Tenant.fromJson(_decode(response));
  }

  Future<List<Customer>> listCustomers(String token) async {
    final response = await _httpClient.get(
      _uri('/api/customers'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = _decode(response);
    return (json['customers'] as List)
        .map((e) => Customer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Customer> createCustomer({
    required String token,
    required CreateCustomerRequest req,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/customers'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return Customer.fromJson(_decode(response));
  }

  Future<Customer> updateCustomer({
    required String token,
    required String id,
    required UpdateCustomerRequest req,
  }) async {
    final response = await _httpClient.patch(
      _uri('/api/customers/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return Customer.fromJson(_decode(response));
  }

  Future<void> deleteCustomer({required String token, required String id}) async {
    final response = await _httpClient.delete(
      _uri('/api/customers/$id'),
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

  Future<List<Supplier>> listSuppliers(String token) async {
    final response = await _httpClient.get(
      _uri('/api/suppliers'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = _decode(response);
    return (json['suppliers'] as List)
        .map((e) => Supplier.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Supplier> createSupplier({
    required String token,
    required CreateSupplierRequest req,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/suppliers'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return Supplier.fromJson(_decode(response));
  }

  Future<Supplier> updateSupplier({
    required String token,
    required String id,
    required UpdateSupplierRequest req,
  }) async {
    final response = await _httpClient.patch(
      _uri('/api/suppliers/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return Supplier.fromJson(_decode(response));
  }

  Future<void> deleteSupplier({required String token, required String id}) async {
    final response = await _httpClient.delete(
      _uri('/api/suppliers/$id'),
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

  Future<List<Article>> listArticles(String token) async {
    final response = await _httpClient.get(
      _uri('/api/articles'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = _decode(response);
    return (json['articles'] as List)
        .map((e) => Article.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Article> createArticle({
    required String token,
    required CreateArticleRequest req,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/articles'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return Article.fromJson(_decode(response));
  }

  Future<Article> updateArticle({
    required String token,
    required String id,
    required UpdateArticleRequest req,
  }) async {
    final response = await _httpClient.patch(
      _uri('/api/articles/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return Article.fromJson(_decode(response));
  }

  Future<void> deleteArticle({required String token, required String id}) async {
    final response = await _httpClient.delete(
      _uri('/api/articles/$id'),
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

  Future<List<Product>> listProducts(String token) async {
    final response = await _httpClient.get(
      _uri('/api/products'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = _decode(response);
    return (json['products'] as List)
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Product> createProduct({
    required String token,
    required CreateProductRequest req,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/products'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return Product.fromJson(_decode(response));
  }

  Future<Product> updateProduct({
    required String token,
    required String id,
    required UpdateProductRequest req,
  }) async {
    final response = await _httpClient.patch(
      _uri('/api/products/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return Product.fromJson(_decode(response));
  }

  Future<void> deleteProduct({required String token, required String id}) async {
    final response = await _httpClient.delete(
      _uri('/api/products/$id'),
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

  Future<Product> confirmProductPrice({required String token, required String id}) async {
    final response = await _httpClient.post(
      _uri('/api/products/$id/confirm-price'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return Product.fromJson(_decode(response));
  }

  Future<Product> rejectProductPrice({required String token, required String id}) async {
    final response = await _httpClient.post(
      _uri('/api/products/$id/reject-price'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return Product.fromJson(_decode(response));
  }

  Future<ArticlePriceImportResult> importArticlePrices({
    required String token,
    required String csv,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/articles/price-import'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(ArticlePriceImportRequest(csv: csv).toJson()),
    );
    return ArticlePriceImportResult.fromJson(_decode(response));
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
