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

  Future<List<Quote>> listQuotes(String token) async {
    final response = await _httpClient.get(
      _uri('/api/quotes'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = _decode(response);
    return (json['quotes'] as List)
        .map((e) => Quote.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Quote> createQuote({
    required String token,
    required CreateQuoteRequest req,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/quotes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return Quote.fromJson(_decode(response));
  }

  Future<Quote> updateQuote({
    required String token,
    required String id,
    required UpdateQuoteRequest req,
  }) async {
    final response = await _httpClient.patch(
      _uri('/api/quotes/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return Quote.fromJson(_decode(response));
  }

  Future<void> deleteQuote({required String token, required String id}) async {
    final response = await _httpClient.delete(
      _uri('/api/quotes/$id'),
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

  Future<Uint8List> getQuotePdf({required String token, required String id}) async {
    final response = await _httpClient.get(
      _uri('/api/quotes/$id/pdf'),
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

  Future<List<Order>> listOrders(String token) async {
    final response = await _httpClient.get(
      _uri('/api/orders'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = _decode(response);
    return (json['orders'] as List)
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Order> createOrder({
    required String token,
    required CreateOrderRequest req,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/orders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return Order.fromJson(_decode(response));
  }

  Future<Order> updateOrder({
    required String token,
    required String id,
    required UpdateOrderRequest req,
  }) async {
    final response = await _httpClient.patch(
      _uri('/api/orders/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return Order.fromJson(_decode(response));
  }

  Future<void> deleteOrder({required String token, required String id}) async {
    final response = await _httpClient.delete(
      _uri('/api/orders/$id'),
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

  Future<Order> convertQuoteToOrder({required String token, required String quoteId}) async {
    final response = await _httpClient.post(
      _uri('/api/quotes/$quoteId/to-order'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return Order.fromJson(_decode(response));
  }

  Future<List<Invoice>> listInvoices(String token) async {
    final response = await _httpClient.get(
      _uri('/api/invoices'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = _decode(response);
    return (json['invoices'] as List)
        .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Invoice> createInvoice({
    required String token,
    required CreateInvoiceRequest req,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/invoices'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return Invoice.fromJson(_decode(response));
  }

  Future<Invoice> updateInvoice({
    required String token,
    required String id,
    required UpdateInvoiceRequest req,
  }) async {
    final response = await _httpClient.patch(
      _uri('/api/invoices/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return Invoice.fromJson(_decode(response));
  }

  Future<void> deleteInvoice({required String token, required String id}) async {
    final response = await _httpClient.delete(
      _uri('/api/invoices/$id'),
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

  Future<Invoice> convertOrderToInvoice({
    required String token,
    required String orderId,
    InvoiceType invoiceType = InvoiceType.standard,
    List<String>? itemIds,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/orders/$orderId/to-invoice'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'invoice_type': invoiceType.toJson(),
        if (itemIds != null) 'item_ids': itemIds,
      }),
    );
    return Invoice.fromJson(_decode(response));
  }

  /// Liefert die Positionen eines Auftrags inkl. `already_invoiced`-Flag —
  /// Basis für die Positions-Checkliste bei Teil-/Abschlags-/Schlussrechnungen.
  Future<List<Map<String, dynamic>>> getBillableOrderItems({
    required String token,
    required String orderId,
  }) async {
    final response = await _httpClient.get(
      _uri('/api/orders/$orderId/billable-items'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = _decode(response);
    return (json['items'] as List).cast<Map<String, dynamic>>();
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

  /// Lädt die Stundenerfassungs-Einträge des angemeldeten Nutzers,
  /// optional auf einen Zeitraum eingeschränkt (Wochenansicht: `from`/`to`
  /// jeweils inklusiv, Format `YYYY-MM-DD`).
  Future<List<TimeEntry>> listTimeEntries({
    required String token,
    DateTime? from,
    DateTime? to,
  }) async {
    final query = <String, String>{
      if (from != null) 'from': _dateOnly(from),
      if (to != null) 'to': _dateOnly(to),
    };
    final response = await _httpClient.get(
      _uri('/api/time-entries').replace(queryParameters: query.isEmpty ? null : query),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = _decode(response);
    return (json['time_entries'] as List)
        .map((e) => TimeEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TimeEntry> createTimeEntry({
    required String token,
    required CreateTimeEntryRequest req,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/time-entries'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return TimeEntry.fromJson(_decode(response));
  }

  Future<TimeEntry> updateTimeEntry({
    required String token,
    required String id,
    required UpdateTimeEntryRequest req,
  }) async {
    final response = await _httpClient.patch(
      _uri('/api/time-entries/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return TimeEntry.fromJson(_decode(response));
  }

  Future<void> deleteTimeEntry({required String token, required String id}) async {
    final response = await _httpClient.delete(
      _uri('/api/time-entries/$id'),
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

  Future<List<Invoice>> listOverdueInvoices(String token) async {
    final response = await _httpClient.get(
      _uri('/api/invoices/overdue'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = _decode(response);
    return (json['invoices'] as List)
        .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Invoice> dunInvoice({required String token, required String id}) async {
    final response = await _httpClient.post(
      _uri('/api/invoices/$id/dun'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return Invoice.fromJson(_decode(response));
  }

  Future<Uint8List> getDunningPdf({required String token, required String id}) async {
    final response = await _httpClient.get(
      _uri('/api/invoices/$id/dunning-pdf'),
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

  Future<List<PurchaseOrder>> listPurchaseOrders(String token) async {
    final response = await _httpClient.get(
      _uri('/api/purchase-orders'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = _decode(response);
    return (json['purchase_orders'] as List)
        .map((e) => PurchaseOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PurchaseOrder> createPurchaseOrder({
    required String token,
    required CreatePurchaseOrderRequest req,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/purchase-orders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return PurchaseOrder.fromJson(_decode(response));
  }

  Future<PurchaseOrder> updatePurchaseOrder({
    required String token,
    required String id,
    required UpdatePurchaseOrderRequest req,
  }) async {
    final response = await _httpClient.patch(
      _uri('/api/purchase-orders/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return PurchaseOrder.fromJson(_decode(response));
  }

  Future<void> deletePurchaseOrder({required String token, required String id}) async {
    final response = await _httpClient.delete(
      _uri('/api/purchase-orders/$id'),
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

  Future<PurchaseOrder> receivePurchaseOrder({
    required String token,
    required String id,
    required ReceivePurchaseOrderRequest req,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/purchase-orders/$id/receive'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return PurchaseOrder.fromJson(_decode(response));
  }

  Future<List<PurchaseProposalGroup>> getPurchaseProposal({required String token, required String orderId}) async {
    final response = await _httpClient.get(
      _uri('/api/orders/$orderId/purchase-proposal'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = _decode(response);
    return (json['proposals'] as List)
        .map((e) => PurchaseProposalGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Project>> listProjects(String token) async {
    final response = await _httpClient.get(
      _uri('/api/projects'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = _decode(response);
    return (json['projects'] as List)
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Project> createProject({
    required String token,
    required CreateProjectRequest req,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/projects'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return Project.fromJson(_decode(response));
  }

  Future<Project> updateProject({
    required String token,
    required String id,
    required UpdateProjectRequest req,
  }) async {
    final response = await _httpClient.patch(
      _uri('/api/projects/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return Project.fromJson(_decode(response));
  }

  Future<void> deleteProject({required String token, required String id}) async {
    final response = await _httpClient.delete(
      _uri('/api/projects/$id'),
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

  Future<List<ProjectTransaction>> listProjectTransactions({
    required String token,
    required String projectId,
  }) async {
    final response = await _httpClient.get(
      _uri('/api/projects/$projectId/transactions'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = _decode(response);
    return (json['project_transactions'] as List)
        .map((e) => ProjectTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProjectTransaction> createProjectTransaction({
    required String token,
    required String projectId,
    required CreateProjectTransactionRequest req,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/projects/$projectId/transactions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return ProjectTransaction.fromJson(_decode(response));
  }

  Future<ProjectTransaction> updateProjectTransaction({
    required String token,
    required String projectId,
    required String id,
    required UpdateProjectTransactionRequest req,
  }) async {
    final response = await _httpClient.patch(
      _uri('/api/projects/$projectId/transactions/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return ProjectTransaction.fromJson(_decode(response));
  }

  Future<void> deleteProjectTransaction({
    required String token,
    required String projectId,
    required String id,
  }) async {
    final response = await _httpClient.delete(
      _uri('/api/projects/$projectId/transactions/$id'),
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

  Future<ProjectProfitLoss> getProjectProfitLoss({required String token, required String projectId}) async {
    final response = await _httpClient.get(
      _uri('/api/projects/$projectId/profit-loss'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return ProjectProfitLoss.fromJson(_decode(response));
  }

  Future<List<MaintenanceContract>> listMaintenanceContracts(String token) async {
    final response = await _httpClient.get(
      _uri('/api/maintenance-contracts'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final json = _decode(response);
    return (json['maintenance_contracts'] as List)
        .map((e) => MaintenanceContract.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MaintenanceContract> createMaintenanceContract({
    required String token,
    required CreateMaintenanceContractRequest req,
  }) async {
    final response = await _httpClient.post(
      _uri('/api/maintenance-contracts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return MaintenanceContract.fromJson(_decode(response));
  }

  Future<MaintenanceContract> updateMaintenanceContract({
    required String token,
    required String id,
    required UpdateMaintenanceContractRequest req,
  }) async {
    final response = await _httpClient.patch(
      _uri('/api/maintenance-contracts/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(req.toJson()),
    );
    return MaintenanceContract.fromJson(_decode(response));
  }

  Future<void> deleteMaintenanceContract({required String token, required String id}) async {
    final response = await _httpClient.delete(
      _uri('/api/maintenance-contracts/$id'),
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

  Future<DashboardSummary> getDashboardSummary(String token) async {
    final response = await _httpClient.get(
      _uri('/api/dashboard/summary'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return DashboardSummary.fromJson(_decode(response));
  }

  Future<Uint8List> exportInvoicesCsv({required String token, DateTime? from, DateTime? to}) async {
    final params = <String, String>{};
    if (from != null) params['from'] = _dateOnly(from);
    if (to != null) params['to'] = _dateOnly(to);

    final response = await _httpClient.get(
      _uri('/api/invoices/export').replace(queryParameters: params.isEmpty ? null : params),
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

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
