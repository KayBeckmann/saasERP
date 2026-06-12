import 'app_user.dart';
import 'tenant.dart';

/// Self-Service-Registrierung: legt einen neuen Mandanten samt Owner-User an.
class RegisterRequest {
  const RegisterRequest({
    required this.companyName,
    required this.email,
    required this.password,
  });

  final String companyName;
  final String email;
  final String password;

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      RegisterRequest(
        companyName: json['company_name'] as String,
        email: json['email'] as String,
        password: json['password'] as String,
      );

  Map<String, dynamic> toJson() => {
        'company_name': companyName,
        'email': email,
        'password': password,
      };
}

class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  factory LoginRequest.fromJson(Map<String, dynamic> json) => LoginRequest(
        email: json['email'] as String,
        password: json['password'] as String,
      );

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

/// Mandantenwechsel für Nutzer mit mehreren Zugängen (Tenant-Auswahl).
class SwitchTenantRequest {
  const SwitchTenantRequest({required this.tenantId});

  final String tenantId;

  factory SwitchTenantRequest.fromJson(Map<String, dynamic> json) =>
      SwitchTenantRequest(tenantId: json['tenant_id'] as String);

  Map<String, dynamic> toJson() => {'tenant_id': tenantId};
}

/// Antwort auf Register/Login: JWT + zugehöriger Mandant/Benutzer.
class AuthResponse {
  const AuthResponse({
    required this.token,
    required this.user,
    required this.tenant,
  });

  final String token;
  final AppUser user;
  final Tenant tenant;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        token: json['token'] as String,
        user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
        tenant: Tenant.fromJson(json['tenant'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'user': user.toJson(),
        'tenant': tenant.toJson(),
      };
}
