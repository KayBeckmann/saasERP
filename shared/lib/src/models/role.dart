/// Bekannte Module für die modulare Rechtevergabe (RF2). Bewusst als
/// Konstanten statt enum: neue Module (z. B. künftige Fachbereiche) lassen
/// sich ergänzen, ohne das Wire-Format/die DB-Spalte (TEXT) zu brechen.
/// `AuthorizationService` im Backend ist die einzige Stelle, die diese
/// Werte tatsächlich gegen `role_permissions` prüft.
abstract class PermissionModule {
  static const customers = 'customers';
  static const suppliers = 'suppliers';
  static const articles = 'articles';
  static const products = 'products';
  static const quotes = 'quotes';
  static const orders = 'orders';
  static const invoices = 'invoices';
  static const purchaseOrders = 'purchase_orders';
  static const projects = 'projects';
  static const timeEntries = 'time_entries';
  static const documents = 'documents';
  static const maintenanceContracts = 'maintenance_contracts';
  static const dashboard = 'dashboard';
  static const tenantConfig = 'tenant_config';
  static const members = 'members';
  static const waas = 'waas';

  static const all = [
    customers, suppliers, articles, products, quotes, orders, invoices,
    purchaseOrders, projects, timeEntries, documents, maintenanceContracts,
    dashboard, tenantConfig, members, waas,
  ];
}

/// Aktionen je Modul (Roadmap RF2: "Ansehen/Erstellen/Ändern/Freigeben/
/// Versenden/Exportieren/Löschen/Stornieren").
abstract class PermissionAction {
  static const view = 'view';
  static const create = 'create';
  static const edit = 'edit';
  static const release = 'release';
  static const send = 'send';
  static const export = 'export';
  static const delete = 'delete';
  static const cancel = 'cancel';

  static const all = [view, create, edit, release, send, export, delete, cancel];
}

/// Eine Berechtigung (Modul × Aktion).
class RolePermission {
  const RolePermission({required this.module, required this.action});

  final String module;
  final String action;

  String get key => '$module:$action';

  factory RolePermission.fromJson(Map<String, dynamic> json) => RolePermission(
        module: json['module'] as String,
        action: json['action'] as String,
      );

  Map<String, dynamic> toJson() => {'module': module, 'action': action};

  @override
  bool operator ==(Object other) =>
      other is RolePermission && other.module == module && other.action == action;

  @override
  int get hashCode => Object.hash(module, action);
}

/// Eine mandantenfähige, anpassbare Rolle samt ihrer Berechtigungen.
class Role {
  const Role({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.isBuiltin,
    required this.isAdminRole,
    required this.createdAt,
    required this.permissions,
  });

  final String id;
  final String tenantId;
  final String name;

  /// Ursprung = eingebaute Vorlage (Admin/Buchhaltung/...). Nur eine
  /// Markierung, keine Sperre — die Rolle bleibt pro Mandant anpassbar.
  final bool isBuiltin;

  /// Governance: die Admin-Rolle eines Mandanten kann nicht gelöscht werden,
  /// ihr letzter Träger kann nicht entfernt/umbesetzt werden.
  final bool isAdminRole;

  final DateTime createdAt;
  final List<RolePermission> permissions;

  bool hasPermission(String module, String action) =>
      permissions.any((p) => p.module == module && p.action == action);

  factory Role.fromJson(Map<String, dynamic> json) => Role(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        name: json['name'] as String,
        isBuiltin: json['is_builtin'] as bool? ?? false,
        isAdminRole: json['is_admin_role'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        permissions: (json['permissions'] as List<dynamic>? ?? [])
            .map((p) => RolePermission.fromJson(p as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'name': name,
        'is_builtin': isBuiltin,
        'is_admin_role': isAdminRole,
        'created_at': createdAt.toIso8601String(),
        'permissions': permissions.map((p) => p.toJson()).toList(),
      };
}

/// Request zum Anlegen/Ändern einer anpassbaren Rolle.
class UpsertRoleRequest {
  const UpsertRoleRequest({required this.name, required this.permissions});

  final String name;
  final List<RolePermission> permissions;

  factory UpsertRoleRequest.fromJson(Map<String, dynamic> json) => UpsertRoleRequest(
        name: json['name'] as String,
        permissions: (json['permissions'] as List<dynamic>? ?? [])
            .map((p) => RolePermission.fromJson(p as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'permissions': permissions.map((p) => p.toJson()).toList(),
      };
}

/// Ein Mitglied eines Mandanten samt seiner Rolle dort (für die
/// Mitgliederverwaltung, RF2).
class TenantMember {
  const TenantMember({
    required this.userId,
    required this.email,
    required this.roleId,
    required this.roleName,
    required this.createdAt,
  });

  final String userId;
  final String email;
  final String roleId;
  final String roleName;
  final DateTime createdAt;

  factory TenantMember.fromJson(Map<String, dynamic> json) => TenantMember(
        userId: json['user_id'] as String,
        email: json['email'] as String,
        roleId: json['role_id'] as String,
        roleName: json['role_name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'email': email,
        'role_id': roleId,
        'role_name': roleName,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Request zum Einladen eines neuen Mitglieds (legt sofort einen Account mit
/// Initialpasswort an — kein separater Einladungs-Flow wie im Kundenportal,
/// da Mitarbeitende i. d. R. vom Admin direkt informiert werden).
class InviteMemberRequest {
  const InviteMemberRequest({
    required this.email,
    required this.initialPassword,
    required this.roleId,
  });

  final String email;
  final String initialPassword;
  final String roleId;

  factory InviteMemberRequest.fromJson(Map<String, dynamic> json) => InviteMemberRequest(
        email: json['email'] as String,
        initialPassword: json['initial_password'] as String,
        roleId: json['role_id'] as String,
      );

  Map<String, dynamic> toJson() => {
        'email': email,
        'initial_password': initialPassword,
        'role_id': roleId,
      };
}
