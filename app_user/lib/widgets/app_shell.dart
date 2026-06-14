import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/articles_screen.dart';
import '../screens/customers_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/dunning_screen.dart';
import '../screens/invoices_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/products_screen.dart';
import '../screens/projects_screen.dart';
import '../screens/purchase_orders_screen.dart';
import '../screens/quotes_screen.dart';
import '../screens/stock_overview_screen.dart';
import '../screens/suppliers_screen.dart';
import '../screens/time_entries_screen.dart';
import '../state/auth_controller.dart';
import '../theme.dart';

/// Module der User-App, wie sie in der Sidebar-Navigation des
/// "Craft-Trade ERP System"-Mockups erscheinen.
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
}

class _NavEntry {
  const _NavEntry(this.item, this.icon, this.label);

  final AppNavItem item;
  final IconData icon;
  final String label;
}

const _navEntries = [
  _NavEntry(AppNavItem.dashboard, Icons.dashboard_outlined, 'Dashboard'),
  _NavEntry(AppNavItem.customers, Icons.people_outline, 'Kunden'),
  _NavEntry(AppNavItem.suppliers, Icons.local_shipping_outlined, 'Lieferanten'),
  _NavEntry(AppNavItem.articles, Icons.inventory_2_outlined, 'Artikel'),
  _NavEntry(AppNavItem.products, Icons.widgets_outlined, 'Produkte'),
  _NavEntry(AppNavItem.quotes, Icons.description_outlined, 'Angebote'),
  _NavEntry(AppNavItem.projects, Icons.folder_outlined, 'Projekte'),
  _NavEntry(AppNavItem.orders, Icons.assignment_outlined, 'Aufträge'),
  _NavEntry(AppNavItem.invoices, Icons.receipt_long_outlined, 'Rechnungen'),
  _NavEntry(AppNavItem.dunning, Icons.warning_amber_outlined, 'Mahnwesen'),
  _NavEntry(AppNavItem.purchaseOrders, Icons.shopping_cart_outlined, 'Bestellungen'),
  _NavEntry(AppNavItem.stock, Icons.warehouse_outlined, 'Bestandsübersicht'),
  _NavEntry(AppNavItem.timeEntries, Icons.timer_outlined, 'Stundenerfassung'),
];

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
  }
}

/// Breakpoints gemäß `mockup/craft_trade_erp_system/DESIGN.md`:
/// Desktop ≥1200px (feste 280px-Sidebar), Tablet 768–1199px (Icon-Rail),
/// Mobile <768px (Drawer/Hamburger).
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
          drawer: isDesktop ? null : Drawer(child: _Sidebar(currentItem: currentItem)),
          body: Row(
            children: [
              if (isDesktop) _Sidebar(currentItem: currentItem),
              if (isTablet && !isDesktop) _IconRail(currentItem: currentItem),
              Expanded(
                child: Column(
                  children: [
                    _Header(title: title, actions: actions, showMenuButton: !isDesktop),
                    const Divider(height: 1),
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

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.actions, required this.showMenuButton});

  final String title;
  final List<Widget>? actions;
  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 64,
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menü',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          ...?actions,
          if (auth.availableTenants.length > 1)
            PopupMenuButton<String>(
              tooltip: 'Mandant wechseln',
              icon: const Icon(Icons.apartment),
              onSelected: (tenantId) => auth.switchTenant(tenantId),
              itemBuilder: (context) => auth.availableTenants
                  .map(
                    (access) => PopupMenuItem(
                      value: access.tenant.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (access.tenant.id == auth.tenant?.id)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.check, size: 18),
                            ),
                          Text(access.tenant.name),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
            onPressed: () => auth.logout(),
          ),
        ],
      ),
    );
  }
}

/// Volle 280px-Sidebar mit Icon + Label, aktiver Eintrag mit
/// Steel-Blue-10%-Hintergrund und 4px-Indikatorbalken in Deep Navy.
class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.currentItem});

  final AppNavItem currentItem;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Container(
      width: AppShell.sidebarWidth,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text(
                auth.tenant?.name ?? 'saasERP',
                style: Theme.of(context).textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final entry in _navEntries)
                    _NavTile(entry: entry, selected: entry.item == currentItem, showLabel: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Schmale Icon-Rail für Tablet-Breite (768–1199px) — gleiche
/// Auswahl-Darstellung wie die volle Sidebar, ohne Beschriftung.
class _IconRail extends StatelessWidget {
  const _IconRail({required this.currentItem});

  final AppNavItem currentItem;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppShell.railWidth,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 12),
            for (final entry in _navEntries)
              _NavTile(entry: entry, selected: entry.item == currentItem, showLabel: false),
          ],
        ),
      ),
    );
  }
}

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
    final content = Container(
      decoration: BoxDecoration(
        color: selected ? steelBlue.withValues(alpha: 0.1) : null,
        border: Border(
          left: BorderSide(color: selected ? deepNavy : Colors.transparent, width: 4),
        ),
      ),
      child: showLabel
          ? ListTile(
              leading: Icon(entry.icon),
              title: Text(entry.label),
              dense: true,
              selected: selected,
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Icon(entry.icon),
            ),
    );

    return Tooltip(
      message: entry.label,
      child: InkWell(
        onTap: selected ? null : () => _navigate(context),
        child: content,
      ),
    );
  }
}
