import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../state/auth_controller.dart';
import 'purchase_order_editor_screen.dart';

/// Listet die Bestellungen des Mandanten und erlaubt Anlegen/Bearbeiten.
class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  late Future<({List<PurchaseOrder> purchaseOrders, List<Supplier> suppliers})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({List<PurchaseOrder> purchaseOrders, List<Supplier> suppliers})> _load() async {
    final auth = context.read<AuthController>();
    final purchaseOrders = await auth.apiClient.listPurchaseOrders(auth.token!);
    final suppliers = await auth.apiClient.listSuppliers(auth.token!);
    return (purchaseOrders: purchaseOrders, suppliers: suppliers);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _openEditor({PurchaseOrder? purchaseOrder}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PurchaseOrderEditorScreen(purchaseOrder: purchaseOrder)),
    );
    if (changed ?? false) _reload();
  }

  String? _supplierName(String? supplierId, List<Supplier> suppliers) {
    if (supplierId == null) return null;
    for (final supplier in suppliers) {
      if (supplier.id == supplierId) return supplier.name;
    }
    return null;
  }

  String _statusLabel(PurchaseOrderStatus status) => switch (status) {
        PurchaseOrderStatus.open => 'Offen',
        PurchaseOrderStatus.ordered => 'Bestellt',
        PurchaseOrderStatus.partiallyDelivered => 'Teilweise geliefert',
        PurchaseOrderStatus.fullyDelivered => 'Vollständig geliefert',
      };

  Color _statusColor(PurchaseOrderStatus status, BuildContext context) => switch (status) {
        PurchaseOrderStatus.open => Theme.of(context).colorScheme.surfaceContainerHighest,
        PurchaseOrderStatus.ordered => Colors.blue.shade100,
        PurchaseOrderStatus.partiallyDelivered => Colors.orange.shade100,
        PurchaseOrderStatus.fullyDelivered => Colors.green.shade100,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bestellungen')),
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
          if (data.purchaseOrders.isEmpty) {
            return const Center(child: Text('Noch keine Bestellungen vorhanden.'));
          }

          return ListView.builder(
            itemCount: data.purchaseOrders.length,
            itemBuilder: (context, index) {
              final purchaseOrder = data.purchaseOrders[index];
              final supplierName = _supplierName(purchaseOrder.supplierId, data.suppliers);

              return ListTile(
                title: Text(purchaseOrder.purchaseOrderNumber),
                subtitle: Text(
                  [
                    ?supplierName,
                    '${purchaseOrder.totalNet.toStringAsFixed(2)} € netto',
                  ].join(' · '),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(purchaseOrder.status, context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_statusLabel(purchaseOrder.status)),
                ),
                onTap: () => _openEditor(purchaseOrder: purchaseOrder),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: 'Neue Bestellung',
        child: const Icon(Icons.add),
      ),
    );
  }
}
