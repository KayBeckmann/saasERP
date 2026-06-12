import 'package:backend/src/auth_service.dart';
import 'package:backend/src/config.dart';
import 'package:backend/src/db.dart';
import 'package:backend/src/repositories/tenant_access_repository.dart';
import 'package:backend/src/repositories/tenant_repository.dart';
import 'package:backend/src/repositories/user_repository.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

final _config = AppConfig.fromEnvironment();
final _pool = createDbPool(_config);
final _authService = AuthService(_config);
final _tenantRepository = TenantRepository(_pool);
final _userRepository = UserRepository(_pool);
final _tenantAccessRepository = TenantAccessRepository(_pool);

Handler middleware(Handler handler) {
  return handler
      .use(_corsHeaders())
      .use(provider<AppConfig>((_) => _config))
      .use(provider<Pool<void>>((_) => _pool))
      .use(provider<AuthService>((_) => _authService))
      .use(provider<TenantRepository>((_) => _tenantRepository))
      .use(provider<UserRepository>((_) => _userRepository))
      .use(provider<TenantAccessRepository>((_) => _tenantAccessRepository));
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
