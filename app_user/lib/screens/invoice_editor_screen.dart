import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/invoice_conversion_dialog.dart';

/// Anlegen/Bearbeiten einer Rechnung: Stammdaten (Kunde, Titel, Status,
/// Fälligkeitsdatum, Notizen) plus Positions-Editor (Freitext, Artikel,
/// Produkt, Stunden) mit Live-Summen — analog zu `OrderEditorScreen`.
class InvoiceEditorScreen extends StatefulWidget {
  const InvoiceEditorScreen({super.key, this.invoice});

  final Invoice? invoice;

  @override
  State<InvoiceEditorScreen> createState() => _InvoiceEditorScreenState();
}

/// Hält die Eingaben einer einzelnen Rechnungsposition.
class _ItemDraft {
  _ItemDraft({
    required this.kind,
    this.articleId,
    this.productId,
    String description = '',
    double quantity = 1,
    String unit = '',
    double unitPrice = 0,
    double vatRate = 19.0,
    String groupLabel = '',
    this.orderItemId,
  })  : descriptionController = TextEditingController(text: description),
        quantityController = TextEditingController(text: _formatNumber(quantity)),
        unitController = TextEditingController(text: unit),
        unitPriceController = TextEditingController(text: _formatNumber(unitPrice)),
        vatRateController = TextEditingController(text: _formatNumber(vatRate)),
        groupLabelController = TextEditingController(text: groupLabel);

  factory _ItemDraft.fromItem(InvoiceItem item) => _ItemDraft(
        kind: item.kind,
        articleId: item.articleId,
        productId: item.productId,
        description: item.description,
        quantity: item.quantity,
        unit: item.unit ?? '',
        unitPrice: item.unitPrice,
        vatRate: item.vatRate,
        groupLabel: item.groupLabel ?? '',
        orderItemId: item.orderItemId,
      );

  InvoiceItemKind kind;
  String? articleId;
  String? productId;

  /// Verweist auf die Auftragsposition, aus der diese Position übernommen
  /// wurde (Doppelabrechnungsschutz) — bleibt beim Speichern erhalten.
  final String? orderItemId;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController unitController;
  final TextEditingController unitPriceController;
  final TextEditingController vatRateController;
  final TextEditingController groupLabelController;

  static String _formatNumber(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  double get quantity => double.tryParse(quantityController.text.trim().replaceAll(',', '.')) ?? 0;

  double get unitPrice => double.tryParse(unitPriceController.text.trim().replaceAll(',', '.')) ?? 0;

  double get vatRate => double.tryParse(vatRateController.text.trim().replaceAll(',', '.')) ?? 19.0;

  double get totalNet => quantity * unitPrice;

  double get totalGross => totalNet * (1 + vatRate / 100);

  String? get groupLabel =>
      groupLabelController.text.trim().isEmpty ? null : groupLabelController.text.trim();

  InvoiceItem toItem() => InvoiceItem(
        kind: kind,
        articleId: articleId,
        productId: productId,
        description: descriptionController.text.trim(),
        quantity: quantity,
        unit: unitController.text.trim().isEmpty ? null : unitController.text.trim(),
        unitPrice: unitPrice,
        vatRate: vatRate,
        groupLabel: groupLabel,
        orderItemId: orderItemId,
      );

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    unitController.dispose();
    unitPriceController.dispose();
    vatRateController.dispose();
    groupLabelController.dispose();
  }
}

class _InvoiceEditorScreenState extends State<InvoiceEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  String? _customerId;
  InvoiceStatus _status = InvoiceStatus.draft;
  DateTime? _dueDate;
  final List<_ItemDraft> _items = [];

  late Future<({List<Customer> customers, List<Article> articles, List<Product> products})> _refsFuture;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final i = widget.invoice;
    _titleController = TextEditingController(text: i?.title ?? '');
    _notesController = TextEditingController(text: i?.notes ?? '');
    _customerId = i?.customerId;
    _status = i?.status ?? InvoiceStatus.draft;
    _dueDate = i?.dueDate;
    if (i != null) {
      _items.addAll(i.items.map(_ItemDraft.fromItem));
    }
    _refsFuture = _loadReferences();
  }

  Future<({List<Customer> customers, List<Article> articles, List<Product> products})> _loadReferences() async {
    final auth = context.read<AuthController>();
    final customers = await auth.apiClient.listCustomers(auth.token!);
    final articles = await auth.apiClient.listArticles(auth.token!);
    final products = await auth.apiClient.listProducts(auth.token!);
    return (customers: customers, articles: articles, products: products);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _totalNet => _items.fold(0, (sum, item) => sum + item.totalNet);

  double get _totalGross => _items.fold(0, (sum, item) => sum + item.totalGross);

  /// Zwischensummen je [_ItemDraft.groupLabel], in Reihenfolge des ersten
  /// Auftretens. Positionen ohne Gruppe werden hier nicht aufgeführt.
  List<InvoiceGroupSummary> _groupSubtotals() {
    final byLabel = <String, List<InvoiceItem>>{};
    final order = <String>[];
    for (final item in _items) {
      final label = item.groupLabel;
      if (label == null) continue;
      if (!byLabel.containsKey(label)) {
        byLabel[label] = [];
        order.add(label);
      }
      byLabel[label]!.add(item.toItem());
    }
    return [for (final label in order) InvoiceGroupSummary(label: label, items: byLabel[label]!)];
  }

  void _addTextItem() {
    setState(() => _items.add(_ItemDraft(kind: InvoiceItemKind.text)));
  }

  void _addHoursItem() {
    setState(() => _items.add(_ItemDraft(kind: InvoiceItemKind.hours, unit: 'h')));
  }

  void _addArticleItem(List<Article> articles) {
    if (articles.isEmpty) return;
    setState(() {
      final article = articles.first;
      _items.add(
        _ItemDraft(
          kind: InvoiceItemKind.article,
          articleId: article.id,
          description: article.name,
          unit: article.unit ?? '',
          unitPrice: article.salePrice ?? 0,
          vatRate: article.vatRate,
        ),
      );
    });
  }

  void _addProductItem(List<Product> products) {
    if (products.isEmpty) return;
    setState(() {
      final product = products.first;
      _items.add(
        _ItemDraft(
          kind: InvoiceItemKind.product,
          productId: product.id,
          description: product.name,
          unitPrice: product.salePrice,
          vatRate: product.vatRate,
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

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final auth = context.read<AuthController>();
    final items = _items.map((draft) => draft.toItem()).toList();

    try {
      if (widget.invoice == null) {
        await auth.apiClient.createInvoice(
          token: auth.token!,
          req: CreateInvoiceRequest(
            customerId: _customerId,
            title: _titleController.text.trim(),
            dueDate: _dueDate,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            items: items,
          ),
        );
      } else {
        await auth.apiClient.updateInvoice(
          token: auth.token!,
          id: widget.invoice!.id,
          req: UpdateInvoiceRequest(
            customerId: _customerId,
            title: _titleController.text.trim(),
            status: _status,
            dueDate: _dueDate,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            items: items,
            invoiceType: widget.invoice!.invoiceType,
            priorInvoicedTotal: widget.invoice!.priorInvoicedTotal,
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.invoice != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Rechnung ${widget.invoice!.invoiceNumber}' : 'Neue Rechnung'),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            tooltip: 'Speichern',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
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
                  if (widget.invoice != null) ...[
                    Wrap(
                      spacing: 8,
                      children: [
                        if (widget.invoice!.orderId != null)
                          const Chip(label: Text('Erzeugt aus Auftrag')),
                        if (widget.invoice!.invoiceType != InvoiceType.standard)
                          Chip(label: Text(invoiceTypeLabel(widget.invoice!.invoiceType))),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Titel *'),
                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Pflichtfeld' : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _customerId,
                          decoration: const InputDecoration(labelText: 'Kunde'),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('— kein Kunde —')),
                            for (final customer in refs.customers)
                              DropdownMenuItem<String?>(value: customer.id, child: Text(customer.name)),
                          ],
                          onChanged: (value) => setState(() => _customerId = value),
                        ),
                      ),
                      if (isEdit) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<InvoiceStatus>(
                            initialValue: _status,
                            decoration: const InputDecoration(labelText: 'Status'),
                            items: [
                              for (final status in InvoiceStatus.values)
                                DropdownMenuItem(value: status, child: Text(_statusLabel(status))),
                            ],
                            onChanged: (value) => setState(() => _status = value ?? InvoiceStatus.draft),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickDueDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Fälligkeitsdatum'),
                      child: Text(
                        _dueDate == null
                            ? '— kein Datum —'
                            : '${_dueDate!.day.toString().padLeft(2, '0')}.'
                                '${_dueDate!.month.toString().padLeft(2, '0')}.'
                                '${_dueDate!.year}',
                      ),
                    ),
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
                  for (var i = 0; i < _items.length; i++) _buildItemRow(context, i, refs),
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
                      OutlinedButton.icon(
                        onPressed: () => _addProductItem(refs.products),
                        icon: const Icon(Icons.widgets_outlined),
                        label: const Text('Produkt'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addHoursItem,
                        icon: const Icon(Icons.schedule_outlined),
                        label: const Text('Stunden'),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  if (_groupSubtotals().isNotEmpty) ...[
                    Text('Zwischensummen', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final group in _groupSubtotals())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(group.label!),
                            Text(
                              '${group.totalNet.toStringAsFixed(2)} € netto '
                              '/ ${group.totalGross.toStringAsFixed(2)} € brutto',
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 24),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Netto: ${_totalNet.toStringAsFixed(2)} €'),
                        Text(
                          'Brutto: ${_totalGross.toStringAsFixed(2)} €',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (widget.invoice?.priorInvoicedTotal != null) ...[
                          Text(
                            'Abzgl. bereits gestellter Rechnungen: '
                            '-${widget.invoice!.priorInvoicedTotal!.toStringAsFixed(2)} €',
                          ),
                          Text(
                            'Zu zahlen: '
                            '${(_totalGross - widget.invoice!.priorInvoicedTotal!).toStringAsFixed(2)} €',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
    ({List<Customer> customers, List<Article> articles, List<Product> products}) refs,
  ) {
    final item = _items[index];

    Widget descriptionField;
    switch (item.kind) {
      case InvoiceItemKind.article:
        descriptionField = DropdownButtonFormField<String>(
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
              item.unitPriceController.text = _ItemDraft._formatNumber(article.salePrice ?? 0);
              item.vatRateController.text = _ItemDraft._formatNumber(article.vatRate);
            });
          },
        );
      case InvoiceItemKind.product:
        descriptionField = DropdownButtonFormField<String>(
          initialValue: item.productId,
          decoration: const InputDecoration(labelText: 'Produkt'),
          items: [
            for (final product in refs.products)
              DropdownMenuItem(value: product.id, child: Text(product.name)),
          ],
          onChanged: (value) {
            final product = refs.products.firstWhere((p) => p.id == value);
            setState(() {
              item.productId = value;
              item.descriptionController.text = product.name;
              item.unitPriceController.text = _ItemDraft._formatNumber(product.salePrice);
              item.vatRateController.text = _ItemDraft._formatNumber(product.vatRate);
            });
          },
        );
      case InvoiceItemKind.text:
      case InvoiceItemKind.hours:
        descriptionField = TextFormField(
          controller: item.descriptionController,
          decoration: const InputDecoration(labelText: 'Beschreibung'),
        );
    }

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
            TextFormField(
              controller: item.groupLabelController,
              decoration: const InputDecoration(
                labelText: 'Gruppe (optional)',
                hintText: 'z. B. Elektroinstallation — für Zwischensummen',
              ),
              onChanged: (_) => setState(() {}),
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
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: item.vatRateController,
                    decoration: const InputDecoration(labelText: 'MwSt. %'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text('${item.totalNet.toStringAsFixed(2)} € netto'),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(InvoiceStatus status) => switch (status) {
        InvoiceStatus.draft => 'Entwurf',
        InvoiceStatus.sent => 'Versendet',
        InvoiceStatus.paid => 'Bezahlt',
        InvoiceStatus.overdue => 'Überfällig',
        InvoiceStatus.cancelled => 'Storniert',
      };
}
