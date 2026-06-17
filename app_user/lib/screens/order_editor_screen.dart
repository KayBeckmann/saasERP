import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/closing_invoice_dialog.dart';
import '../widgets/invoice_conversion_dialog.dart';
import '../widgets/material_invoice_dialog.dart';

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
  })  : descriptionController = TextEditingController(text: description),
        quantityController = TextEditingController(text: _fmt(quantity)),
        unitController = TextEditingController(text: unit),
        unitPriceController = TextEditingController(text: _fmt(unitPrice)),
        vatRateController = TextEditingController(text: _fmt(vatRate));

  factory _ItemDraft.fromItem(OrderItem item) => _ItemDraft(
        kind: item.kind,
        articleId: item.articleId,
        productId: item.productId,
        description: item.description,
        quantity: item.quantity,
        unit: item.unit ?? '',
        unitPrice: item.unitPrice,
        vatRate: item.vatRate,
      );

  OrderItemKind kind;
  String? articleId;
  String? productId;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController unitController;
  final TextEditingController unitPriceController;
  final TextEditingController vatRateController;

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  double get quantity =>
      double.tryParse(quantityController.text.trim().replaceAll(',', '.')) ?? 0;
  double get unitPrice =>
      double.tryParse(unitPriceController.text.trim().replaceAll(',', '.')) ?? 0;
  double get vatRate =>
      double.tryParse(vatRateController.text.trim().replaceAll(',', '.')) ?? 19.0;
  double get totalNet => quantity * unitPrice;
  double get totalGross => totalNet * (1 + vatRate / 100);

  OrderItem toItem({String? groupLabel}) => OrderItem(
        kind: kind,
        articleId: articleId,
        productId: productId,
        description: descriptionController.text.trim(),
        quantity: quantity,
        unit: unitController.text.trim().isEmpty ? null : unitController.text.trim(),
        unitPrice: unitPrice,
        vatRate: vatRate,
        groupLabel: groupLabel,
      );

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    unitController.dispose();
    unitPriceController.dispose();
    vatRateController.dispose();
  }
}

class _GroupDraft {
  _GroupDraft({String title = ''})
      : titleController = TextEditingController(text: title);

  final TextEditingController titleController;
  final List<_ItemDraft> items = [];

  String get title => titleController.text.trim();
  double get totalNet => items.fold(0.0, (s, i) => s + i.totalNet);
  double get totalGross => items.fold(0.0, (s, i) => s + i.totalGross);

  void dispose() {
    titleController.dispose();
    for (final item in items) {
      item.dispose();
    }
  }
}

typedef _Refs = ({
  List<Customer> customers,
  List<Article> articles,
  List<Product> products,
  List<Project> projects
});

/// Anlegen/Bearbeiten eines Auftrags mit Gruppen-Editor nach miniERP-Vorbild.
class OrderEditorScreen extends StatefulWidget {
  const OrderEditorScreen({super.key, this.order});

  final Order? order;

  @override
  State<OrderEditorScreen> createState() => _OrderEditorScreenState();
}

class _OrderEditorScreenState extends State<OrderEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  String? _customerId;
  String? _projectId;
  OrderStatus _status = OrderStatus.open;

  final List<_ItemDraft> _ungrouped = [];
  final List<_GroupDraft> _groups = [];

  late Future<_Refs> _refsFuture;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    _titleController = TextEditingController(text: o?.title ?? '');
    _notesController = TextEditingController(text: o?.notes ?? '');
    _customerId = o?.customerId;
    _projectId = o?.projectId;
    _status = o?.status ?? OrderStatus.open;

    if (o != null) {
      for (final item in o.items) {
        final label = item.groupLabel;
        if (label == null || label.isEmpty) {
          _ungrouped.add(_ItemDraft.fromItem(item));
        } else {
          var group = _groups.where((g) => g.title == label).firstOrNull;
          if (group == null) {
            group = _GroupDraft(title: label);
            _groups.add(group);
          }
          group.items.add(_ItemDraft.fromItem(item));
        }
      }
    }

    _refsFuture = _loadReferences();
  }

  Future<_Refs> _loadReferences() async {
    final auth = context.read<AuthController>();
    final customers = await auth.apiClient.listCustomers(auth.token!);
    final articles = await auth.apiClient.listArticles(auth.token!);
    final products = await auth.apiClient.listProducts(auth.token!);
    final projects = await auth.apiClient.listProjects(auth.token!);
    return (
      customers: customers,
      articles: articles,
      products: products,
      projects: projects
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    for (final item in _ungrouped) {
      item.dispose();
    }
    for (final group in _groups) {
      group.dispose();
    }
    super.dispose();
  }

  double get _totalNet =>
      _ungrouped.fold(0.0, (s, i) => s + i.totalNet) +
      _groups.fold(0.0, (s, g) => s + g.totalNet);

  double get _totalGross =>
      _ungrouped.fold(0.0, (s, i) => s + i.totalGross) +
      _groups.fold(0.0, (s, g) => s + g.totalGross);

  List<OrderItem> _collectItems() => [
        ..._ungrouped.map((d) => d.toItem()),
        for (final group in _groups)
          for (final item in group.items)
            item.toItem(groupLabel: group.title.isEmpty ? null : group.title),
      ];

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final auth = context.read<AuthController>();
    try {
      if (widget.order == null) {
        await auth.apiClient.createOrder(
          token: auth.token!,
          req: CreateOrderRequest(
            customerId: _customerId,
            projectId: _projectId,
            title: _titleController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            items: _collectItems(),
          ),
        );
      } else {
        await auth.apiClient.updateOrder(
          token: auth.token!,
          id: widget.order!.id,
          req: UpdateOrderRequest(
            customerId: _customerId,
            projectId: _projectId,
            title: _titleController.text.trim(),
            status: _status,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            items: _collectItems(),
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

  Future<void> _convertToInvoice() async {
    final auth = context.read<AuthController>();
    final choice = await showInvoiceConversionDialog(
      context: context,
      apiClient: auth.apiClient,
      token: auth.token!,
      orderId: widget.order!.id,
    );
    if (choice == null || !mounted) return;

    try {
      final invoice = await auth.apiClient.convertOrderToInvoice(
        token: auth.token!,
        orderId: widget.order!.id,
        invoiceType: choice.invoiceType,
        itemIds: choice.itemIds,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rechnung ${invoice.invoiceNumber} erstellt.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fehler: ${e.message}')));
    }
  }

  Future<void> _createMaterialInvoice() async {
    final auth = context.read<AuthController>();
    await showMaterialInvoiceDialog(
      context: context,
      apiClient: auth.apiClient,
      token: auth.token!,
      orderId: widget.order!.id,
    );
  }

  Future<void> _createClosingInvoice() async {
    await showClosingInvoiceDialog(
      context: context,
      orderId: widget.order!.id,
    );
  }

  String _statusLabel(OrderStatus status) => switch (status) {
        OrderStatus.open => 'Offen',
        OrderStatus.inProgress => 'In Bearbeitung',
        OrderStatus.completed => 'Abgeschlossen',
        OrderStatus.cancelled => 'Storniert',
      };

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.order != null;

    return AppShell(
      currentItem: AppNavItem.orders,
      title: isEdit ? 'Auftrag ${widget.order!.orderNumber}' : 'Neuer Auftrag',
      actions: [
        if (isEdit) ...[
          PopupMenuButton<String>(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Rechnung erstellen',
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'standard',
                child: Text('Rechnung erstellen'),
              ),
              const PopupMenuItem(
                value: 'material',
                child: Text('Materialabschlag erstellen'),
              ),
              const PopupMenuItem(
                value: 'closing',
                child: Text('Endrechnung erstellen'),
              ),
            ],
            onSelected: (value) {
              if (value == 'standard') _convertToInvoice();
              if (value == 'material') _createMaterialInvoice();
              if (value == 'closing') _createClosingInvoice();
            },
          ),
        ],
        IconButton(
          icon: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
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
                  if (widget.order?.quoteId != null) ...[
                    Text('Erzeugt aus Angebot',
                        style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 8),
                  ],
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Titel *'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Pflichtfeld'
                            : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _customerId,
                          decoration: const InputDecoration(labelText: 'Kunde'),
                          items: [
                            const DropdownMenuItem<String?>(
                                value: null, child: Text('— kein Kunde —')),
                            for (final customer in refs.customers)
                              DropdownMenuItem<String?>(
                                  value: customer.id,
                                  child: Text(customer.name)),
                          ],
                          onChanged: (value) =>
                              setState(() => _customerId = value),
                        ),
                      ),
                      if (isEdit) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<OrderStatus>(
                            initialValue: _status,
                            decoration:
                                const InputDecoration(labelText: 'Status'),
                            items: [
                              for (final status in OrderStatus.values)
                                DropdownMenuItem(
                                    value: status,
                                    child: Text(_statusLabel(status))),
                            ],
                            onChanged: (value) => setState(
                                () => _status = value ?? OrderStatus.open),
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
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('— kein Projekt —')),
                      for (final project in refs.projects)
                        DropdownMenuItem<String?>(
                          value: project.id,
                          child: Text(
                              '${project.projectNumber} · ${project.name}'),
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
                  const SizedBox(height: 20),
                  _buildUngroupedSection(context, refs),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _groups.length; i++) ...[
                    _buildGroupCard(context, i, refs),
                    const SizedBox(height: 12),
                  ],
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _groups.add(_GroupDraft())),
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('Gruppe hinzufügen'),
                  ),
                  const Divider(height: 32),
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
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUngroupedSection(BuildContext context, _Refs refs) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(context, 'Allgemeine Positionen'),
          if (_ungrouped.isNotEmpty) ...[
            const Divider(height: 1),
            _buildItemsHeader(),
            for (var i = 0; i < _ungrouped.length; i++)
              _buildItemRow(
                context,
                i,
                _ungrouped[i],
                () => setState(() {
                  _ungrouped[i].dispose();
                  _ungrouped.removeAt(i);
                }),
                refs,
              ),
          ],
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: _buildAddButtons(
              refs,
              onText: () => setState(
                  () => _ungrouped.add(_ItemDraft(kind: OrderItemKind.text))),
              onArticle: refs.articles.isEmpty
                  ? null
                  : () {
                      final a = refs.articles.first;
                      setState(() => _ungrouped.add(_ItemDraft(
                            kind: OrderItemKind.article,
                            articleId: a.id,
                            description: a.name,
                            unit: a.unit ?? '',
                            unitPrice: a.salePrice ?? 0,
                            vatRate: a.vatRate,
                          )));
                    },
              onProduct: refs.products.isEmpty
                  ? null
                  : () {
                      final p = refs.products.first;
                      setState(() => _ungrouped.add(_ItemDraft(
                            kind: OrderItemKind.product,
                            productId: p.id,
                            description: p.name,
                            unitPrice: p.salePrice,
                            vatRate: p.vatRate,
                          )));
                    },
              onHours: () => setState(() =>
                  _ungrouped.add(_ItemDraft(kind: OrderItemKind.hours, unit: 'h'))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, int gi, _Refs refs) {
    final group = _groups[gi];
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: colorSurfaceContainerLow,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_outlined, size: 18, color: steelBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: group.titleController,
                    decoration: const InputDecoration(
                      hintText: 'Gruppenname eingeben …',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Gruppe entfernen',
                  onPressed: () => setState(() {
                    _groups[gi].dispose();
                    _groups.removeAt(gi);
                  }),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          if (group.items.isNotEmpty) ...[
            const Divider(height: 1),
            _buildItemsHeader(),
            for (var i = 0; i < group.items.length; i++)
              _buildItemRow(
                context,
                i,
                group.items[i],
                () => setState(() {
                  group.items[i].dispose();
                  group.items.removeAt(i);
                }),
                refs,
              ),
          ],
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: _buildAddButtons(
              refs,
              onText: () => setState(
                  () => group.items.add(_ItemDraft(kind: OrderItemKind.text))),
              onArticle: refs.articles.isEmpty
                  ? null
                  : () {
                      final a = refs.articles.first;
                      setState(() => group.items.add(_ItemDraft(
                            kind: OrderItemKind.article,
                            articleId: a.id,
                            description: a.name,
                            unit: a.unit ?? '',
                            unitPrice: a.salePrice ?? 0,
                            vatRate: a.vatRate,
                          )));
                    },
              onProduct: refs.products.isEmpty
                  ? null
                  : () {
                      final p = refs.products.first;
                      setState(() => group.items.add(_ItemDraft(
                            kind: OrderItemKind.product,
                            productId: p.id,
                            description: p.name,
                            unitPrice: p.salePrice,
                            vatRate: p.vatRate,
                          )));
                    },
              onHours: () => setState(() =>
                  group.items.add(_ItemDraft(kind: OrderItemKind.hours, unit: 'h'))),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: colorSurfaceContainerLow,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  group.title.isEmpty ? 'Gruppe' : group.title,
                  style: const TextStyle(
                      color: colorOnSurfaceVariant, fontSize: 12),
                ),
                Text(
                  '${group.totalNet.toStringAsFixed(2)} € netto',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: colorOnSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: colorSurfaceContainerLow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: colorOnSurfaceVariant),
      ),
    );
  }

  Widget _buildAddButtons(
    _Refs refs, {
    required VoidCallback onText,
    required VoidCallback? onArticle,
    required VoidCallback? onProduct,
    required VoidCallback onHours,
  }) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        TextButton.icon(
          onPressed: onText,
          icon: const Icon(Icons.notes_outlined, size: 16),
          label: const Text('Freitext'),
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
        ),
        TextButton.icon(
          onPressed: onArticle,
          icon: const Icon(Icons.inventory_2_outlined, size: 16),
          label: const Text('Artikel'),
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
        ),
        TextButton.icon(
          onPressed: onProduct,
          icon: const Icon(Icons.widgets_outlined, size: 16),
          label: const Text('Produkt'),
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
        ),
        TextButton.icon(
          onPressed: onHours,
          icon: const Icon(Icons.schedule_outlined, size: 16),
          label: const Text('Stunden'),
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
        ),
      ],
    );
  }

  static const _compactDec = InputDecoration(
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    border: OutlineInputBorder(),
  );

  Widget _buildItemsHeader() {
    const style = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54);
    return Container(
      color: const Color(0xFFF5F5F5),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: const [
          SizedBox(width: 28),
          SizedBox(width: 4),
          Expanded(flex: 4, child: Text('Beschreibung', style: style)),
          SizedBox(width: 4),
          SizedBox(width: 72, child: Text('Menge', style: style, textAlign: TextAlign.right)),
          SizedBox(width: 4),
          SizedBox(width: 52, child: Text('Einh.', style: style)),
          SizedBox(width: 4),
          SizedBox(width: 80, child: Text('EP €', style: style, textAlign: TextAlign.right)),
          SizedBox(width: 4),
          SizedBox(width: 60, child: Text('MwSt %', style: style, textAlign: TextAlign.right)),
          SizedBox(width: 4),
          SizedBox(width: 84, child: Text('Gesamt €', style: style, textAlign: TextAlign.right)),
          SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildItemRow(
    BuildContext context,
    int index,
    _ItemDraft item,
    VoidCallback onRemove,
    _Refs refs,
  ) {
    Widget descriptionField;
    switch (item.kind) {
      case OrderItemKind.article:
        descriptionField = DropdownButtonFormField<String>(
          initialValue: item.articleId,
          isExpanded: true,
          decoration: _compactDec.copyWith(labelText: 'Artikel'),
          items: [
            for (final article in refs.articles)
              DropdownMenuItem(
                  value: article.id,
                  child: Text(article.name, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (value) {
            if (value == null) return;
            final article = refs.articles.firstWhere((a) => a.id == value);
            setState(() {
              item.articleId = value;
              item.descriptionController.text = article.name;
              item.unitController.text = article.unit ?? '';
              item.unitPriceController.text =
                  _ItemDraft._fmt(article.salePrice ?? 0);
              item.vatRateController.text = _ItemDraft._fmt(article.vatRate);
            });
          },
        );
      case OrderItemKind.product:
        descriptionField = DropdownButtonFormField<String>(
          initialValue: item.productId,
          isExpanded: true,
          decoration: _compactDec.copyWith(labelText: 'Produkt'),
          items: [
            for (final product in refs.products)
              DropdownMenuItem(
                  value: product.id,
                  child: Text(product.name, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (value) {
            if (value == null) return;
            final product = refs.products.firstWhere((p) => p.id == value);
            setState(() {
              item.productId = value;
              item.descriptionController.text = product.name;
              item.unitPriceController.text =
                  _ItemDraft._fmt(product.salePrice);
              item.vatRateController.text = _ItemDraft._fmt(product.vatRate);
            });
          },
        );
      case OrderItemKind.text:
      case OrderItemKind.hours:
        descriptionField = TextFormField(
          controller: item.descriptionController,
          decoration: _compactDec.copyWith(
            hintText: item.kind == OrderItemKind.hours
                ? 'Leistungsbeschreibung …'
                : 'Freitext …',
          ),
        );
    }

    return Container(
      color: index.isOdd ? const Color(0xFFFAFAFA) : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${index + 1}',
              style: const TextStyle(color: Colors.black38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(flex: 4, child: descriptionField),
          const SizedBox(width: 4),
          SizedBox(
            width: 72,
            child: TextFormField(
              controller: item.quantityController,
              decoration: _compactDec,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 52,
            child: TextFormField(
              controller: item.unitController,
              decoration: _compactDec,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 80,
            child: TextFormField(
              controller: item.unitPriceController,
              decoration: _compactDec,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 60,
            child: TextFormField(
              controller: item.vatRateController,
              decoration: _compactDec,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 84,
            child: Text(
              '${item.totalNet.toStringAsFixed(2)} €',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          SizedBox(
            width: 36,
            child: IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.red),
              tooltip: 'Position entfernen',
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}
