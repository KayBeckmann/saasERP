import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import 'order_editor_screen.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechnung erstellen?'),
        content: Text('Aus Auftrag ${order.orderNumber} eine neue Rechnung erzeugen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Erstellen')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final auth = context.read<AuthController>();
    try {
      final invoice = await auth.apiClient.convertOrderToInvoice(token: auth.token!, orderId: order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rechnung ${invoice.invoiceNumber} erstellt.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: ${e.message}')));
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

  Color _statusColor(OrderStatus status, BuildContext context) => switch (status) {
        OrderStatus.open => Theme.of(context).colorScheme.surfaceContainerHighest,
        OrderStatus.inProgress => Colors.blue.shade100,
        OrderStatus.completed => Colors.green.shade100,
        OrderStatus.cancelled => Colors.red.shade100,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aufträge')),
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
          if (data.orders.isEmpty) {
            return const Center(child: Text('Noch keine Aufträge vorhanden.'));
          }

          return ListView.builder(
            itemCount: data.orders.length,
            itemBuilder: (context, index) {
              final order = data.orders[index];
              final customerName = _customerName(order.customerId, data.customers);

              return ListTile(
                title: Text('${order.orderNumber} — ${order.title}'),
                subtitle: Text(
                  [
                    ?customerName,
                    '${order.totalGross.toStringAsFixed(2)} €',
                  ].join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(order.status, context),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_statusLabel(order.status)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.receipt_long_outlined),
                      tooltip: 'Rechnung erstellen',
                      onPressed: () => _convertToInvoice(order),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Löschen',
                      onPressed: () => _delete(order),
                    ),
                  ],
                ),
                onTap: () => _openEditor(order: order),
              );
            },
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
