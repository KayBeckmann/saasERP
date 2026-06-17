import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/app_shell.dart';

/// Anlegen/Bearbeiten einer Bestellung: Lieferant, Status, Notizen plus
/// Positions-Editor (Artikel oder Freitext) und — im Bearbeitungsmodus —
/// Wareneingangs-Erfassung je Position.
class PurchaseOrderEditorScreen extends StatefulWidget {
  const PurchaseOrderEditorScreen({super.key, this.purchaseOrder, this.initial});

  /// Vorhandene Bestellung zum Bearbeiten.
  final PurchaseOrder? purchaseOrder;

  /// Vorbelegung für eine neue Bestellung (z. B. aus dem Bestellvorschlag).
  final CreatePurchaseOrderRequest? initial;

  @override
  State<PurchaseOrderEditorScreen> createState() => _PurchaseOrderEditorScreenState();
}

/// Hält die Eingaben einer einzelnen Bestellposition.
class _POItemDraft {
  _POItemDraft({
    this.id,
    this.articleId,
    String description = '',
    double quantity = 1,
    this.quantityDelivered = 0,
    String unit = '',
    double unitPrice = 0,
  })  : descriptionController = TextEditingController(text: description),
        quantityController = TextEditingController(text: _formatNumber(quantity)),
        unitController = TextEditingController(text: unit),
        unitPriceController = TextEditingController(text: _formatNumber(unitPrice)),
        deliveredController = TextEditingController(text: '0');

  factory _POItemDraft.fromItem(PurchaseOrderItem item) => _POItemDraft(
        id: item.id,
        articleId: item.articleId,
        description: item.description,
        quantity: item.quantity,
        quantityDelivered: item.quantityDelivered,
        unit: item.unit ?? '',
        unitPrice: item.unitPrice,
      );

  String? id;
  String? articleId;
  final double quantityDelivered;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController unitController;
  final TextEditingController unitPriceController;

  /// Eingabe für einen neuen Wareneingang (zusätzlich zu [quantityDelivered]).
  final TextEditingController deliveredController;

  static String _formatNumber(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  double get quantity => double.tryParse(quantityController.text.trim().replaceAll(',', '.')) ?? 0;

  double get unitPrice => double.tryParse(unitPriceController.text.trim().replaceAll(',', '.')) ?? 0;

  double get delivered => double.tryParse(deliveredController.text.trim().replaceAll(',', '.')) ?? 0;

  double get totalNet => quantity * unitPrice;

  bool get isFullyDelivered => quantityDelivered >= quantity;

  PurchaseOrderItem toItem() => PurchaseOrderItem(
        id: id,
        articleId: articleId,
        description: descriptionController.text.trim(),
        quantity: quantity,
        quantityDelivered: quantityDelivered,
        unit: unitController.text.trim().isEmpty ? null : unitController.text.trim(),
        unitPrice: unitPrice,
      );

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    unitController.dispose();
    unitPriceController.dispose();
    deliveredController.dispose();
  }
}

class _PurchaseOrderEditorScreenState extends State<PurchaseOrderEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  String? _supplierId;
  String? _projectId;
  PurchaseOrderStatus _status = PurchaseOrderStatus.open;
  final List<_POItemDraft> _items = [];

  late Future<({List<Supplier> suppliers, List<Article> articles, List<Project> projects})> _refsFuture;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final po = widget.purchaseOrder;
    final initial = widget.initial;
    _notesController = TextEditingController(text: po?.notes ?? initial?.notes ?? '');
    _supplierId = po?.supplierId ?? initial?.supplierId;
    _projectId = po?.projectId ?? initial?.projectId;
    _status = po?.status ?? PurchaseOrderStatus.open;
    if (po != null) {
      _items.addAll(po.items.map(_POItemDraft.fromItem));
    } else if (initial != null) {
      _items.addAll(initial.items.map((item) => _POItemDraft.fromItem(item)));
    }
    _refsFuture = _loadReferences();
  }

  Future<({List<Supplier> suppliers, List<Article> articles, List<Project> projects})> _loadReferences() async {
    final auth = context.read<AuthController>();
    final suppliers = await auth.apiClient.listSuppliers(auth.token!);
    final articles = await auth.apiClient.listArticles(auth.token!);
    final projects = await auth.apiClient.listProjects(auth.token!);
    return (suppliers: suppliers, articles: articles, projects: projects);
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _totalNet => _items.fold(0, (sum, item) => sum + item.totalNet);

  void _addTextItem() {
    setState(() => _items.add(_POItemDraft()));
  }

  void _addArticleItem(List<Article> articles) {
    if (articles.isEmpty) return;
    setState(() {
      final article = articles.first;
      _items.add(
        _POItemDraft(
          articleId: article.id,
          description: article.name,
          unit: article.unit ?? '',
          unitPrice: article.purchasePrice ?? 0,
        ),
      );
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      setState(() => _error = 'Bestellung benötigt mindestens eine Position.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final auth = context.read<AuthController>();
    final items = _items.map((draft) => draft.toItem()).toList();

    try {
      if (widget.purchaseOrder == null) {
        await auth.apiClient.createPurchaseOrder(
          token: auth.token!,
          req: CreatePurchaseOrderRequest(
            supplierId: _supplierId,
            orderId: widget.initial?.orderId,
            projectId: _projectId,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            items: items,
          ),
        );
      } else {
        await auth.apiClient.updatePurchaseOrder(
          token: auth.token!,
          id: widget.purchaseOrder!.id,
          req: UpdatePurchaseOrderRequest(
            supplierId: _supplierId,
            projectId: _projectId,
            status: _status,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            items: items,
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _receiveDelivery() async {
    final itemsToReceive = <ReceivePurchaseOrderItem>[];
    for (final item in _items) {
      if (item.id == null) continue;
      if (item.delivered <= 0) continue;
      itemsToReceive.add(ReceivePurchaseOrderItem(id: item.id!, delivered: item.delivered));
    }
    if (itemsToReceive.isEmpty) {
      setState(() => _error = 'Bitte mindestens eine gelieferte Menge angeben.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final auth = context.read<AuthController>();
    try {
      final updated = await auth.apiClient.receivePurchaseOrder(
        token: auth.token!,
        id: widget.purchaseOrder!.id,
        req: ReceivePurchaseOrderRequest(items: itemsToReceive),
      );
      if (mounted) Navigator.pop(context, true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wareneingang erfasst — Status: ${_statusLabel(updated.status)}')),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showPdf() async {
    final auth = context.read<AuthController>();
    try {
      final bytes = await auth.apiClient.getPurchaseOrderPdf(
          token: auth.token!, id: widget.purchaseOrder!.id);
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: '${widget.purchaseOrder!.purchaseOrderNumber}.pdf',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('PDF-Fehler: ${e.message}')));
    }
  }

  String _statusLabel(PurchaseOrderStatus status) => switch (status) {
        PurchaseOrderStatus.open => 'Offen',
        PurchaseOrderStatus.ordered => 'Bestellt',
        PurchaseOrderStatus.partiallyDelivered => 'Teilweise geliefert',
        PurchaseOrderStatus.fullyDelivered => 'Vollständig geliefert',
      };

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.purchaseOrder != null;

    return AppShell(
      currentItem: AppNavItem.purchaseOrders,
      title: isEdit ? 'Bestellung ${widget.purchaseOrder!.purchaseOrderNumber}' : 'Neue Bestellung',
      actions: [
        if (isEdit)
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'PDF',
            onPressed: _showPdf,
          ),
        IconButton(
          icon: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_outlined),
          tooltip: 'Speichern',
          onPressed: _saving ? null : _save,
        ),
      ],
      body: FutureBuilder(
        future: _refsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final refs = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.purchaseOrder?.orderId != null) ...[
                    Text('Erzeugt aus Auftrag', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _supplierId,
                          decoration: const InputDecoration(labelText: 'Lieferant'),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('— kein Lieferant —')),
                            for (final supplier in refs.suppliers)
                              DropdownMenuItem<String?>(value: supplier.id, child: Text(supplier.name)),
                          ],
                          onChanged: (value) => setState(() => _supplierId = value),
                        ),
                      ),
                      if (isEdit) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<PurchaseOrderStatus>(
                            initialValue: _status,
                            decoration: const InputDecoration(labelText: 'Status'),
                            items: [
                              for (final status in PurchaseOrderStatus.values)
                                DropdownMenuItem(value: status, child: Text(_statusLabel(status))),
                            ],
                            onChanged: (value) => setState(() => _status = value ?? PurchaseOrderStatus.open),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: _projectId,
                    decoration: const InputDecoration(labelText: 'Projekt'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('— kein Projekt —')),
                      for (final project in refs.projects)
                        DropdownMenuItem<String?>(
                          value: project.id,
                          child: Text('${project.projectNumber} · ${project.name}'),
                        ),
                    ],
                    onChanged: (value) => setState(() => _projectId = value),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(labelText: 'Notizen'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Text('Positionen', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _items.length; i++) _buildItemRow(context, i, refs, isEdit),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _addTextItem,
                        icon: const Icon(Icons.notes_outlined),
                        label: const Text('Freitext'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _addArticleItem(refs.articles),
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('Artikel'),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Netto: ${_totalNet.toStringAsFixed(2)} €',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  if (isEdit &&
                      _status != PurchaseOrderStatus.fullyDelivered &&
                      _items.any((item) => item.id != null)) ...[
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _receiveDelivery,
                        icon: const Icon(Icons.local_shipping_outlined),
                        label: const Text('Wareneingang buchen'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemRow(
    BuildContext context,
    int index,
    ({List<Supplier> suppliers, List<Article> articles, List<Project> projects}) refs,
    bool isEdit,
  ) {
    final item = _items[index];

    final Widget descriptionField = item.articleId != null
        ? DropdownButtonFormField<String>(
            initialValue: item.articleId,
            decoration: const InputDecoration(labelText: 'Artikel'),
            items: [
              for (final article in refs.articles)
                DropdownMenuItem(value: article.id, child: Text(article.name)),
            ],
            onChanged: (value) {
              final article = refs.articles.firstWhere((a) => a.id == value);
              setState(() {
                item.articleId = value;
                item.descriptionController.text = article.name;
                item.unitController.text = article.unit ?? '';
                item.unitPriceController.text = _POItemDraft._formatNumber(article.purchasePrice ?? 0);
              });
            },
          )
        : TextFormField(
            controller: item.descriptionController,
            decoration: const InputDecoration(labelText: 'Beschreibung'),
          );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: descriptionField),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Position entfernen',
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.quantityController,
                    decoration: const InputDecoration(labelText: 'Menge'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: item.unitController,
                    decoration: const InputDecoration(labelText: 'Einheit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: item.unitPriceController,
                    decoration: const InputDecoration(labelText: 'Preis (€)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (isEdit && item.id != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Geliefert: ${item.quantityDelivered.toStringAsFixed(2)} / ${item.quantity.toStringAsFixed(2)}'
                      '${item.isFullyDelivered ? ' ✓' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (!item.isFullyDelivered)
                    SizedBox(
                      width: 140,
                      child: TextFormField(
                        controller: item.deliveredController,
                        decoration: const InputDecoration(labelText: 'Neu geliefert'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                ],
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: Text('${item.totalNet.toStringAsFixed(2)} € netto'),
            ),
          ],
        ),
      ),
    );
  }
}
