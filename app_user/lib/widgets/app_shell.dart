import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../screens/articles_screen.dart';
import '../screens/customers_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/dunning_screen.dart';
import '../screens/invoices_screen.dart';
import '../screens/maintenance_contracts_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/products_screen.dart';
import '../screens/projects_screen.dart';
import '../screens/purchase_orders_screen.dart';
import '../screens/quotes_screen.dart';
import '../screens/stock_overview_screen.dart';
import '../screens/suppliers_screen.dart';
import '../screens/time_entries_screen.dart';
import '../screens/users_screen.dart';
import '../state/auth_controller.dart';
import '../theme.dart';

enum AppNavItem {
  dashboard,
  customers,
  suppliers,
  articles,
  products,
  quotes,
  projects,
  orders,
  invoices,
  dunning,
  purchaseOrders,
  stock,
  timeEntries,
  maintenanceContracts,
  users,
}

class _NavEntry {
  const _NavEntry(this.item, this.icon, this.label);

  final AppNavItem item;
  final IconData icon;
  final String label;
}

const _navEntries = [
  _NavEntry(AppNavItem.dashboard, Icons.dashboard_outlined, 'Dashboard'),
  _NavEntry(AppNavItem.customers, Icons.group_outlined, 'Kunden'),
  _NavEntry(AppNavItem.quotes, Icons.description_outlined, 'Angebote'),
  _NavEntry(AppNavItem.orders, Icons.assignment_outlined, 'Aufträge'),
  _NavEntry(AppNavItem.invoices, Icons.receipt_outlined, 'Rechnungen'),
  _NavEntry(AppNavItem.dunning, Icons.assignment_late_outlined, 'Mahnwesen'),
  _NavEntry(AppNavItem.articles, Icons.inventory_2_outlined, 'Artikel & Produkte'),
  _NavEntry(AppNavItem.purchaseOrders, Icons.shopping_cart_outlined, 'Bestellungen'),
  _NavEntry(AppNavItem.stock, Icons.warehouse_outlined, 'Lager'),
  _NavEntry(AppNavItem.projects, Icons.account_tree_outlined, 'Projekte'),
  _NavEntry(AppNavItem.timeEntries, Icons.timer_outlined, 'Stundenerfassung'),
  _NavEntry(AppNavItem.maintenanceContracts, Icons.handshake_outlined, 'Wartungsverträge'),
  _NavEntry(AppNavItem.suppliers, Icons.local_shipping_outlined, 'Lieferanten'),
];

// Einträge, die nur für Owner sichtbar sind
const _ownerOnlyNavEntries = [
  _NavEntry(AppNavItem.users, Icons.manage_accounts_outlined, 'Benutzerverwaltung'),
];

// Items that open screens which also serve as landing screens for sub-items.
// "Artikel & Produkte" maps to ArticlesScreen but ProductsScreen is a child.
Widget _screenFor(AppNavItem item) {
  switch (item) {
    case AppNavItem.dashboard:
      return const DashboardScreen();
    case AppNavItem.customers:
      return const CustomersScreen();
    case AppNavItem.suppliers:
      return const SuppliersScreen();
    case AppNavItem.articles:
      return const ArticlesScreen();
    case AppNavItem.products:
      return const ProductsScreen();
    case AppNavItem.quotes:
      return const QuotesScreen();
    case AppNavItem.projects:
      return const ProjectsScreen();
    case AppNavItem.orders:
      return const OrdersScreen();
    case AppNavItem.invoices:
      return const InvoicesScreen();
    case AppNavItem.dunning:
      return const DunningScreen();
    case AppNavItem.purchaseOrders:
      return const PurchaseOrdersScreen();
    case AppNavItem.stock:
      return const StockOverviewScreen();
    case AppNavItem.timeEntries:
      return const TimeEntriesScreen();
    case AppNavItem.maintenanceContracts:
      return const MaintenanceContractsScreen();
    case AppNavItem.users:
      return const UsersScreen();
  }
}

/// AppShell gemäß Mockup "Craft-Trade ERP System":
/// - Desktop ≥1200px: feste 280px-Sidebar
/// - Tablet 768–1199px: 72px Icon-Rail
/// - Mobile <768px: Drawer
///
/// [title] wird als headline-lg im Page-Header über [body] gerendert,
/// nicht im TopBar — damit stimmt die Hierachie mit dem Mockup überein.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.currentItem,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  static const double desktopBreakpoint = 1200;
  static const double tabletBreakpoint = 768;
  static const double sidebarWidth = 280;
  static const double railWidth = 72;

  final AppNavItem currentItem;
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= desktopBreakpoint;
        final isTablet = width >= tabletBreakpoint;

        return Scaffold(
          backgroundColor: colorSurface,
          drawer: isDesktop ? null : Drawer(child: _Sidebar(currentItem: currentItem)),
          body: Row(
            children: [
              if (isDesktop) _Sidebar(currentItem: currentItem),
              if (isTablet && !isDesktop) _IconRail(currentItem: currentItem),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(showMenuButton: !isDesktop),
                    const Divider(height: 1),
                    _PageHeader(title: title, actions: actions),
                    Expanded(child: body),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }
}

/// TopBar: Suchleiste links + Notification/Help/Account-Icons rechts.
/// Kein Seitentitel — der gehört in [_PageHeader].
class _TopBar extends StatelessWidget {
  const _TopBar({required this.showMenuButton});

  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Container(
      height: 64,
      color: colorSurfaceContainerLowest,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: colorOnSurfaceVariant),
              tooltip: 'Menü',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 8),
          ],
          // Suchleiste
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: colorSurfaceContainerLow,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.search, size: 18, color: colorOnSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Suchen...',
                          hintStyle: TextStyle(color: colorOnSurfaceVariant, fontSize: 14),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 14, color: colorOnSurface),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          // Icon-Buttons rechts
          _TopBarIconButton(
            icon: Icons.notifications_outlined,
            tooltip: 'Benachrichtigungen',
            onPressed: () {},
          ),
          _TopBarIconButton(
            icon: Icons.help_outline,
            tooltip: 'Hilfe',
            onPressed: () {},
          ),
          if (auth.availableTenants.length > 1)
            PopupMenuButton<String>(
              tooltip: 'Mandant wechseln',
              icon: const Icon(Icons.apartment, color: colorOnSurfaceVariant),
              onSelected: (tenantId) => auth.switchTenant(tenantId),
              itemBuilder: (context) => auth.availableTenants
                  .map(
                    (access) => PopupMenuItem(
                      value: access.tenant.id,
                      child: Row(
                        children: [
                          if (access.tenant.id == auth.tenant?.id)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.check, size: 16),
                            ),
                          Text(access.tenant.name),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          _TopBarIconButton(
            icon: Icons.account_circle_outlined,
            tooltip: auth.user?.email ?? 'Konto',
            onPressed: () => auth.logout(),
          ),
        ],
      ),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 22, color: colorOnSurfaceVariant),
        ),
      ),
    );
  }
}

/// Seitentitel + Action-Buttons — direkt über dem Body-Inhalt,
/// nicht im TopBar (gemäß Mockup headline-lg im Content-Bereich).
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colorSurface,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: deepNavy,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (actions != null) ...[
            const SizedBox(width: 12),
            ...actions!,
          ],
        ],
      ),
    );
  }
}

/// Volle 280px-Sidebar: weiß, rechter Border, Logo-Header,
/// Nav-Items gemäß Mockup, Bottom-Bereich (Hilfe/Abmelden).
class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.currentItem});

  final AppNavItem currentItem;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Container(
      width: AppShell.sidebarWidth,
      decoration: const BoxDecoration(
        color: colorSurfaceContainerLowest,
        border: Border(right: BorderSide(color: colorOutlineVariant)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo-Header: handyman-Icon + "saasERP" + Firmenname
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: deepNavy,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.handyman, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'saasERP',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: deepNavy,
                            height: 1.2,
                          ),
                        ),
                        if (auth.tenant?.name != null)
                          Text(
                            auth.tenant!.name,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colorOnSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: colorOutlineVariant),
            // Nav-Einträge
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final entry in _navEntries)
                    _NavTile(
                      entry: entry,
                      selected: entry.item == currentItem,
                      showLabel: true,
                    ),
                  if (auth.user?.role == UserRole.owner) ...[
                    const Divider(height: 16, indent: 16, endIndent: 16),
                    for (final entry in _ownerOnlyNavEntries)
                      _NavTile(
                        entry: entry,
                        selected: entry.item == currentItem,
                        showLabel: true,
                      ),
                  ],
                ],
              ),
            ),
            // Bottom-Bereich: Abmelden
            const Divider(height: 1, color: colorOutlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _BottomNavTile(
                    icon: Icons.help_outline,
                    label: 'Hilfe',
                    onTap: () {},
                  ),
                  _BottomNavTile(
                    icon: Icons.logout,
                    label: 'Abmelden',
                    onTap: () => auth.logout(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Schmale 72px Icon-Rail für Tablet.
class _IconRail extends StatelessWidget {
  const _IconRail({required this.currentItem});

  final AppNavItem currentItem;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Container(
      width: AppShell.railWidth,
      decoration: const BoxDecoration(
        color: colorSurfaceContainerLowest,
        border: Border(right: BorderSide(color: colorOutlineVariant)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: deepNavy,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.handyman, size: 20, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final entry in _navEntries)
                    _NavTile(entry: entry, selected: entry.item == currentItem, showLabel: false),
                  if (auth.user?.role == UserRole.owner)
                    for (final entry in _ownerOnlyNavEntries)
                      _NavTile(entry: entry, selected: entry.item == currentItem, showLabel: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nav-Item exakt nach Mockup: `px-md py-sm gap-md text-title-md`,
/// aktiv: `bg-secondary/10` + `border-l-4 border-primary`.
class _NavTile extends StatelessWidget {
  const _NavTile({required this.entry, required this.selected, required this.showLabel});

  final _NavEntry entry;
  final bool selected;
  final bool showLabel;

  void _navigate(BuildContext context) {
    if (entry.item == AppNavItem.dashboard) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _screenFor(entry.item)));
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: showLabel ? '' : entry.label,
      child: InkWell(
        onTap: selected ? null : () => _navigate(context),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? steelBlue.withValues(alpha: 0.1) : null,
            border: Border(
              left: BorderSide(
                color: selected ? deepNavy : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: showLabel ? 16 : 0,
            vertical: 10,
          ),
          child: showLabel
              ? Row(
                  children: [
                    Icon(
                      entry.icon,
                      size: 20,
                      color: selected ? deepNavy : colorOnSurfaceVariant,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        entry.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: selected ? deepNavy : colorOnSurfaceVariant,
                          letterSpacing: 0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Icon(
                    entry.icon,
                    size: 20,
                    color: selected ? deepNavy : colorOnSurfaceVariant,
                  ),
                ),
        ),
      ),
    );
  }
}

class _BottomNavTile extends StatelessWidget {
  const _BottomNavTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colorOnSurfaceVariant),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorOnSurfaceVariant,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
