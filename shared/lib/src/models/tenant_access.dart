import 'tenant.dart';

/// Zugriff eines Nutzers auf einen Mandanten samt Rolle in diesem Mandanten —
/// Grundlage für die Mandanten-/Tenant-Auswahl bei Nutzern mit mehreren
/// Zugängen (z. B. Berater).
class TenantAccess {
  const TenantAccess({required this.tenant, required this.role});

  final Tenant tenant;
  final String role;

  factory TenantAccess.fromJson(Map<String, dynamic> json) => TenantAccess(
        tenant: Tenant.fromJson(json['tenant'] as Map<String, dynamic>),
        role: json['role'] as String,
      );

  Map<String, dynamic> toJson() => {
        'tenant': tenant.toJson(),
        'role': role,
      };
}
