import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/app_data_table.dart';
import '../widgets/app_shell.dart';
import '../widgets/invoice_conversion_dialog.dart';
import '../widgets/purchase_proposal_dialog.dart';
import '../widgets/status_chip.dart';
import 'order_editor_screen.dart';
import 'purchase_order_editor_screen.dart';

/// Listet die Aufträge des Mandanten und erlaubt Anlegen/Bearbeiten/Löschen.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<({List<Order> orders, List<Customer> customers})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({List<Order> orders, List<Customer> customers})> _load() async {
    final auth = context.read<AuthController>();
    final orders = await auth.apiClient.listOrders(auth.token!);
    final customers = await auth.apiClient.listCustomers(auth.token!);
    return (orders: orders, customers: customers);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _openEditor({Order? order}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OrderEditorScreen(order: order)),
    );
    if (changed ?? false) _reload();
  }

  Future<void> _delete(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auftrag löschen?'),
        content: Text('Auftrag ${order.orderNumber} wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final auth = context.read<AuthController>();
    await auth.apiClient.deleteOrder(token: auth.token!, id: order.id);
    _reload();
  }

  Future<void> _convertToInvoice(Order order) async {
    final auth = context.read<AuthController>();
    final choice = await showInvoiceConversionDialog(
      context: context,
      apiClient: auth.apiClient,
      token: auth.token!,
      orderId: order.id,
    );
    if (choice == null) return;
    if (!mounted) return;

    try {
      final invoice = await auth.apiClient.convertOrderToInvoice(
        token: auth.token!,
        orderId: order.id,
        invoiceType: choice.invoiceType,
        itemIds: choice.itemIds,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rechnung ${invoice.invoiceNumber} erstellt.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: ${e.message}')));
    }
  }

  Future<void> _createPurchaseOrderFromProposal(Order order) async {
    final auth = context.read<AuthController>();
    List<PurchaseProposalGroup> proposals;
    try {
      proposals = await auth.apiClient.getPurchaseProposal(token: auth.token!, orderId: order.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: ${e.message}')));
      return;
    }
    if (!mounted) return;

    if (proposals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kein Bestellbedarf — Lagerbestand deckt den Auftrag.')),
      );
      return;
    }

    final group = await showPurchaseProposalDialog(context: context, proposals: proposals);
    if (group == null) return;
    if (!mounted) return;

    final items = group.items
        .map(
          (item) => PurchaseOrderItem(
            articleId: item.articleId,
            description: item.description,
            quantity: item.orderQuantity,
            unit: item.unit,
            unitPrice: item.unitPrice ?? 0,
          ),
        )
        .toList();

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseOrderEditorScreen(
          initial: CreatePurchaseOrderRequest(
            supplierId: group.supplierId,
            orderId: order.id,
            items: items,
          ),
        ),
      ),
    );
    if ((changed ?? false) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bestellung erstellt.')));
    }
  }

  String? _customerName(String? customerId, List<Customer> customers) {
    if (customerId == null) return null;
    for (final customer in customers) {
      if (customer.id == customerId) return customer.name;
    }
    return null;
  }

  String _statusLabel(OrderStatus status) => switch (status) {
        OrderStatus.open => 'Offen',
        OrderStatus.inProgress => 'In Bearbeitung',
        OrderStatus.completed => 'Abgeschlossen',
        OrderStatus.cancelled => 'Storniert',
      };

  StatusTone _statusTone(OrderStatus status) => switch (status) {
        OrderStatus.open => StatusTone.warning,
        OrderStatus.inProgress => StatusTone.info,
        OrderStatus.completed => StatusTone.success,
        OrderStatus.cancelled => StatusTone.error,
      };

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentItem: AppNavItem.orders,
      title: 'Aufträge',
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final data = snapshot.data!;
          return AppDataTable(
            emptyLabel: 'Noch keine Aufträge vorhanden.',
            trailingWidth: 140,
            columns: const [
              AppDataColumn('Auftrag', flex: 3),
              AppDataColumn('Kunde', flex: 2),
              AppDataColumn('Betrag', numeric: true, flex: 2),
              AppDataColumn('Status', flex: 1),
            ],
            rows: [
              for (final order in data.orders)
                AppDataRow(
                  onTap: () => _openEditor(order: order),
                  cells: [
                    Text('${order.orderNumber} — ${order.title}'),
                    Text(_customerName(order.customerId, data.customers) ?? '-'),
                    Text('${order.totalGross.toStringAsFixed(2)} €'),
                    StatusChip(label: _statusLabel(order.status), tone: _statusTone(order.status)),
                  ],
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.receipt_long_outlined),
                        tooltip: 'Rechnung erstellen',
                        onPressed: () => _convertToInvoice(order),
                      ),
                      IconButton(
                        icon: const Icon(Icons.local_shipping_outlined),
                        tooltip: 'Bestellvorschlag',
                        onPressed: () => _createPurchaseOrderFromProposal(order),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Löschen',
                        onPressed: () => _delete(order),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
