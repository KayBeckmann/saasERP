import 'package:saaserp_shared/saaserp_shared.dart';

/// Eingebaute Rollenvorlagen (Roadmap RF2: "Admin", "Buchhaltung",
/// "Vertrieb", "Einkauf", "Lager", "Steuerbüro", "Nur Lesen"). Werden pro
/// Mandant bei der Registrierung als eigene (anpassbare) Rollen angelegt —
/// siehe `RoleRepository.ensureBuiltinRoles`.
///
/// Die konkrete Aufteilung ist ein sinnvoller Startpunkt (die Roadmap gibt
/// nur Namen vor, keine exakte Rechtematrix) und bewusst konservativ: GoBD-
/// relevante Belege (invoices) sind z. B. für keine Vorlage standardmäßig
/// löschbar, nur stornierbar. Der Mandanten-Admin kann jede Vorlage danach
/// frei anpassen.
class RoleTemplate {
  const RoleTemplate({
    required this.name,
    required this.isAdminRole,
    required this.permissions,
  });

  final String name;
  final bool isAdminRole;
  final List<RolePermission> permissions;
}

const _fullAccessModules = [
  PermissionModule.customers,
  PermissionModule.suppliers,
  PermissionModule.articles,
  PermissionModule.products,
  PermissionModule.quotes,
  PermissionModule.orders,
  PermissionModule.invoices,
  PermissionModule.purchaseOrders,
  PermissionModule.projects,
  PermissionModule.timeEntries,
  PermissionModule.documents,
  PermissionModule.maintenanceContracts,
  PermissionModule.dashboard,
  PermissionModule.waas,
];

List<RolePermission> _grant(List<String> modules, List<String> actions) => [
      for (final module in modules)
        for (final action in actions) RolePermission(module: module, action: action),
    ];

List<RolePermission> get _adminPermissions => [
      ..._grant(_fullAccessModules, PermissionAction.all),
      ..._grant([PermissionModule.tenantConfig, PermissionModule.members], PermissionAction.all),
    ];

List<RolePermission> get _buchhaltungPermissions => [
      ..._grant(
        [
          PermissionModule.invoices,
          PermissionModule.quotes,
          PermissionModule.orders,
          PermissionModule.purchaseOrders,
          PermissionModule.customers,
          PermissionModule.suppliers,
          PermissionModule.timeEntries,
          PermissionModule.documents,
          PermissionModule.maintenanceContracts,
          PermissionModule.waas,
        ],
        [PermissionAction.view, PermissionAction.edit, PermissionAction.export],
      ),
      ..._grant([PermissionModule.invoices], [
        PermissionAction.create,
        PermissionAction.release,
        PermissionAction.send,
        PermissionAction.cancel,
      ]),
      ..._grant([PermissionModule.dashboard], [PermissionAction.view]),
    ];

List<RolePermission> get _vertriebPermissions => [
      ..._grant(
        [PermissionModule.quotes, PermissionModule.orders, PermissionModule.customers],
        [PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.send],
      ),
      ..._grant([PermissionModule.products, PermissionModule.articles, PermissionModule.invoices], [PermissionAction.view]),
      ..._grant([PermissionModule.dashboard], [PermissionAction.view]),
    ];

List<RolePermission> get _einkaufPermissions => [
      ..._grant(
        [PermissionModule.purchaseOrders, PermissionModule.suppliers, PermissionModule.articles],
        [PermissionAction.view, PermissionAction.create, PermissionAction.edit, PermissionAction.release],
      ),
      ..._grant([PermissionModule.products], [PermissionAction.view]),
      ..._grant([PermissionModule.dashboard], [PermissionAction.view]),
    ];

List<RolePermission> get _lagerPermissions => [
      ..._grant([PermissionModule.articles], [PermissionAction.view, PermissionAction.edit]),
      ..._grant([PermissionModule.purchaseOrders, PermissionModule.products], [PermissionAction.view]),
    ];

List<RolePermission> get _steuerbueroPermissions => [
      ..._grant(
        [
          PermissionModule.invoices,
          PermissionModule.quotes,
          PermissionModule.orders,
          PermissionModule.purchaseOrders,
          PermissionModule.customers,
          PermissionModule.suppliers,
          PermissionModule.timeEntries,
          PermissionModule.projects,
          PermissionModule.documents,
          PermissionModule.dashboard,
        ],
        [PermissionAction.view, PermissionAction.export],
      ),
    ];

List<RolePermission> get _nurLesenPermissions => _grant(_fullAccessModules, [PermissionAction.view]);

final List<RoleTemplate> builtinRoleTemplates = [
  RoleTemplate(name: 'Admin', isAdminRole: true, permissions: _adminPermissions),
  RoleTemplate(name: 'Buchhaltung', isAdminRole: false, permissions: _buchhaltungPermissions),
  RoleTemplate(name: 'Vertrieb', isAdminRole: false, permissions: _vertriebPermissions),
  RoleTemplate(name: 'Einkauf', isAdminRole: false, permissions: _einkaufPermissions),
  RoleTemplate(name: 'Lager', isAdminRole: false, permissions: _lagerPermissions),
  RoleTemplate(name: 'Steuerbüro', isAdminRole: false, permissions: _steuerbueroPermissions),
  RoleTemplate(name: 'Nur Lesen', isAdminRole: false, permissions: _nurLesenPermissions),
];
