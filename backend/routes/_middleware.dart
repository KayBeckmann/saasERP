import 'package:backend/src/auth_service.dart';
import 'package:backend/src/config.dart';
import 'package:backend/src/db.dart';
import 'package:backend/src/repositories/article_repository.dart';
import 'package:backend/src/repositories/customer_portal_account_repository.dart';
import 'package:backend/src/repositories/customer_repository.dart';
import 'package:backend/src/repositories/dashboard_repository.dart';
import 'package:backend/src/repositories/document_repository.dart';
import 'package:backend/src/repositories/invoice_repository.dart';
import 'package:backend/src/repositories/maintenance_contract_repository.dart';
import 'package:backend/src/repositories/number_sequence_repository.dart';
import 'package:backend/src/repositories/order_repository.dart';
import 'package:backend/src/repositories/product_repository.dart';
import 'package:backend/src/repositories/project_repository.dart';
import 'package:backend/src/repositories/project_transaction_repository.dart';
import 'package:backend/src/repositories/purchase_order_repository.dart';
import 'package:backend/src/repositories/quote_repository.dart';
import 'package:backend/src/repositories/supplier_repository.dart';
import 'package:backend/src/repositories/tenant_access_repository.dart';
import 'package:backend/src/repositories/tenant_encryption_key_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/repositories/time_entry_repository.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:backend/src/tenant_encryption_service.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

final _config = AppConfig.fromEnvironment();
final _pool = createDbPool(_config);
final _authService = AuthService(_config);
final _tenantRepository = TenantRepository(_pool);
final _userRepository = UserRepository(_pool);
final _tenantAccessRepository = TenantAccessRepository(_pool);
final _tenantEncryptionKeyRepository = TenantEncryptionKeyRepository(_pool);
final _tenantEncryptionService = TenantEncryptionService(_config, _tenantEncryptionKeyRepository);
final _numberSequenceRepository = NumberSequenceRepository(_pool);
final _customerRepository = CustomerRepository(_pool, _tenantEncryptionService, _numberSequenceRepository);
final _customerPortalAccountRepository = CustomerPortalAccountRepository(_pool, _config);
final _supplierRepository = SupplierRepository(_pool, _tenantEncryptionService);
final _articleRepository = ArticleRepository(_pool);
final _productRepository = ProductRepository(_pool);
final _quoteRepository = QuoteRepository(_pool, _numberSequenceRepository);
final _orderRepository = OrderRepository(_pool, _numberSequenceRepository);
final _invoiceRepository = InvoiceRepository(_pool, _numberSequenceRepository);
final _timeEntryRepository = TimeEntryRepository(_pool);
final _purchaseOrderRepository = PurchaseOrderRepository(_pool, _numberSequenceRepository);
final _projectRepository = ProjectRepository(_pool, _numberSequenceRepository);
final _projectTransactionRepository = ProjectTransactionRepository(_pool);
final _maintenanceContractRepository = MaintenanceContractRepository(_pool, _numberSequenceRepository);
final _documentRepository = DocumentRepository(_pool);
final _dashboardRepository = DashboardRepository(
  _quoteRepository,
  _orderRepository,
  _purchaseOrderRepository,
  _invoiceRepository,
  _timeEntryRepository,
);

Handler middleware(Handler handler) {
  return handler
      .use(_corsHeaders())
      .use(provider<AppConfig>((_) => _config))
      .use(provider<Pool<void>>((_) => _pool))
      .use(provider<AuthService>((_) => _authService))
      .use(provider<TenantRepository>((_) => _tenantRepository))
      .use(provider<UserRepository>((_) => _userRepository))
      .use(provider<TenantAccessRepository>((_) => _tenantAccessRepository))
      .use(provider<TenantEncryptionKeyRepository>((_) => _tenantEncryptionKeyRepository))
      .use(provider<TenantEncryptionService>((_) => _tenantEncryptionService))
      .use(provider<NumberSequenceRepository>((_) => _numberSequenceRepository))
      .use(provider<CustomerRepository>((_) => _customerRepository))
      .use(provider<CustomerPortalAccountRepository>((_) => _customerPortalAccountRepository))
      .use(provider<SupplierRepository>((_) => _supplierRepository))
      .use(provider<ArticleRepository>((_) => _articleRepository))
      .use(provider<ProductRepository>((_) => _productRepository))
      .use(provider<QuoteRepository>((_) => _quoteRepository))
      .use(provider<OrderRepository>((_) => _orderRepository))
      .use(provider<InvoiceRepository>((_) => _invoiceRepository))
      .use(provider<TimeEntryRepository>((_) => _timeEntryRepository))
      .use(provider<PurchaseOrderRepository>((_) => _purchaseOrderRepository))
      .use(provider<ProjectRepository>((_) => _projectRepository))
      .use(provider<ProjectTransactionRepository>((_) => _projectTransactionRepository))
      .use(provider<MaintenanceContractRepository>((_) => _maintenanceContractRepository))
      .use(provider<DocumentRepository>((_) => _documentRepository))
      .use(provider<DashboardRepository>((_) => _dashboardRepository));
}

/// CORS-Header für Aufrufe der User-/Kunden-App von einer anderen Origin.
/// Erlaubte Origin via `CORS_ORIGIN` (.env), Default `*` für lokale Entwicklung.
Middleware _corsHeaders() {
  return (handler) {
    return (context) async {
      final headers = {
        'Access-Control-Allow-Origin': _config.corsOrigin,
        'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      };

      if (context.request.method == HttpMethod.options) {
        return Response(headers: headers);
      }

      final response = await handler(context);
      return response.copyWith(headers: {...response.headers, ...headers});
    };
  };
}
