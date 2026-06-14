import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../state/auth_controller.dart';
import '../widgets/app_data_table.dart';
import '../widgets/app_shell.dart';
import '../widgets/status_chip.dart';
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

  StatusTone _statusTone(PurchaseOrderStatus status) => switch (status) {
        PurchaseOrderStatus.open => StatusTone.warning,
        PurchaseOrderStatus.ordered => StatusTone.info,
        PurchaseOrderStatus.partiallyDelivered => StatusTone.warning,
        PurchaseOrderStatus.fullyDelivered => StatusTone.success,
      };

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentItem: AppNavItem.purchaseOrders,
      title: 'Bestellungen',
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
            emptyLabel: 'Noch keine Bestellungen vorhanden.',
            columns: const [
              AppDataColumn('Bestellung', flex: 3),
              AppDataColumn('Lieferant', flex: 2),
              AppDataColumn('Betrag (netto)', numeric: true, flex: 2),
              AppDataColumn('Status', flex: 1),
            ],
            rows: [
              for (final purchaseOrder in data.purchaseOrders)
                AppDataRow(
                  onTap: () => _openEditor(purchaseOrder: purchaseOrder),
                  cells: [
                    Text(purchaseOrder.purchaseOrderNumber),
                    Text(_supplierName(purchaseOrder.supplierId, data.suppliers) ?? '-'),
                    Text('${purchaseOrder.totalNet.toStringAsFixed(2)} €'),
                    StatusChip(
                      label: _statusLabel(purchaseOrder.status),
                      tone: _statusTone(purchaseOrder.status),
                    ),
                  ],
                ),
            ],
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
