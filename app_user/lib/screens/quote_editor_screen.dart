import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../theme.dart';
import '../widgets/app_shell.dart';

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

  factory _ItemDraft.fromItem(QuoteItem item) => _ItemDraft(
        kind: item.kind,
        articleId: item.articleId,
        productId: item.productId,
        description: item.description,
        quantity: item.quantity,
        unit: item.unit ?? '',
        unitPrice: item.unitPrice,
        vatRate: item.vatRate,
      );

  QuoteItemKind kind;
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

  QuoteItem toItem({String? groupLabel}) => QuoteItem(
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
  List<Product> products
});

/// Anlegen/Bearbeiten eines Angebots mit Gruppen-Editor nach miniERP-Vorbild:
/// Gruppen sind eigenständige Karten mit editierbarem Titel und
/// per-Gruppe-Aktionsbuttons. Allgemeine Positionen bilden die erste Karte.
class QuoteEditorScreen extends StatefulWidget {
  const QuoteEditorScreen({super.key, this.quote});

  final Quote? quote;

  @override
  State<QuoteEditorScreen> createState() => _QuoteEditorScreenState();
}

class _QuoteEditorScreenState extends State<QuoteEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  String? _customerId;
  QuoteStatus _status = QuoteStatus.draft;
  DateTime? _validUntil;

  final List<_ItemDraft> _ungrouped = [];
  final List<_GroupDraft> _groups = [];

  late Future<_Refs> _refsFuture;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final q = widget.quote;
    _titleController = TextEditingController(text: q?.title ?? '');
    _notesController = TextEditingController(text: q?.notes ?? '');
    _customerId = q?.customerId;
    _status = q?.status ?? QuoteStatus.draft;
    _validUntil = q?.validUntil;

    if (q != null) {
      for (final item in q.items) {
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
    return (customers: customers, articles: articles, products: products);
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

  List<QuoteItem> _collectItems() => [
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
      if (widget.quote == null) {
        await auth.apiClient.createQuote(
          token: auth.token!,
          req: CreateQuoteRequest(
            customerId: _customerId,
            title: _titleController.text.trim(),
            validUntil: _validUntil,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            items: _collectItems(),
          ),
        );
      } else {
        await auth.apiClient.updateQuote(
          token: auth.token!,
          id: widget.quote!.id,
          req: UpdateQuoteRequest(
            customerId: _customerId,
            title: _titleController.text.trim(),
            status: _status,
            validUntil: _validUntil,
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

  Future<void> _convertToOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('In Auftrag wandeln?'),
        content: Text(
            'Aus Angebot ${widget.quote!.quoteNumber} einen neuen Auftrag erzeugen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Wandeln')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final auth = context.read<AuthController>();
    try {
      final order = await auth.apiClient.convertQuoteToOrder(
          token: auth.token!, quoteId: widget.quote!.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auftrag ${order.orderNumber} erstellt.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fehler: ${e.message}')));
    }
  }

  Future<void> _showPdf() async {
    final auth = context.read<AuthController>();
    try {
      final bytes = await auth.apiClient
          .getQuotePdf(token: auth.token!, id: widget.quote!.id);
      await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: '${widget.quote!.quoteNumber}.pdf');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('PDF-Fehler: ${e.message}')));
    }
  }

  Future<void> _pickValidUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _validUntil = picked);
  }

  String _statusLabel(QuoteStatus status) => switch (status) {
        QuoteStatus.draft => 'Entwurf',
        QuoteStatus.sent => 'Versendet',
        QuoteStatus.accepted => 'Angenommen',
        QuoteStatus.rejected => 'Abgelehnt',
      };

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.quote != null;

    return AppShell(
      currentItem: AppNavItem.quotes,
      title: isEdit ? 'Angebot ${widget.quote!.quoteNumber}' : 'Neues Angebot',
      actions: [
        if (isEdit) ...[
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'PDF',
            onPressed: _showPdf,
          ),
          IconButton(
            icon: const Icon(Icons.assignment_turned_in_outlined),
            tooltip: 'In Auftrag wandeln',
            onPressed: _convertToOrder,
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
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Titel *'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Pflichtfeld'
                            : null,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: _customerId,
                    decoration: const InputDecoration(labelText: 'Kunde'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('— kein Kunde —')),
                      for (final customer in refs.customers)
                        DropdownMenuItem<String?>(
                            value: customer.id, child: Text(customer.name)),
                    ],
                    onChanged: (value) => setState(() => _customerId = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickValidUntil,
                          child: InputDecorator(
                            decoration:
                                const InputDecoration(labelText: 'Gültig bis'),
                            child: Text(
                              _validUntil == null
                                  ? '—'
                                  : '${_validUntil!.day.toString().padLeft(2, '0')}.'
                                      '${_validUntil!.month.toString().padLeft(2, '0')}.'
                                      '${_validUntil!.year}',
                            ),
                          ),
                        ),
                      ),
                      if (isEdit) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<QuoteStatus>(
                            initialValue: _status,
                            decoration:
                                const InputDecoration(labelText: 'Status'),
                            items: [
                              for (final status in QuoteStatus.values)
                                DropdownMenuItem(
                                    value: status,
                                    child: Text(_statusLabel(status))),
                            ],
                            onChanged: (value) => setState(
                                () => _status = value ?? QuoteStatus.draft),
                          ),
                        ),
                      ],
                    ],
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
                  () => _ungrouped.add(_ItemDraft(kind: QuoteItemKind.text))),
              onArticle: refs.articles.isEmpty
                  ? null
                  : () {
                      final a = refs.articles.first;
                      setState(() => _ungrouped.add(_ItemDraft(
                            kind: QuoteItemKind.article,
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
                            kind: QuoteItemKind.product,
                            productId: p.id,
                            description: p.name,
                            unitPrice: p.salePrice,
                            vatRate: p.vatRate,
                          )));
                    },
              onHours: () => setState(() =>
                  _ungrouped.add(_ItemDraft(kind: QuoteItemKind.hours, unit: 'h'))),
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
                  () => group.items.add(_ItemDraft(kind: QuoteItemKind.text))),
              onArticle: refs.articles.isEmpty
                  ? null
                  : () {
                      final a = refs.articles.first;
                      setState(() => group.items.add(_ItemDraft(
                            kind: QuoteItemKind.article,
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
                            kind: QuoteItemKind.product,
                            productId: p.id,
                            description: p.name,
                            unitPrice: p.salePrice,
                            vatRate: p.vatRate,
                          )));
                    },
              onHours: () => setState(() =>
                  group.items.add(_ItemDraft(kind: QuoteItemKind.hours, unit: 'h'))),
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
      case QuoteItemKind.article:
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
      case QuoteItemKind.product:
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
      case QuoteItemKind.text:
      case QuoteItemKind.hours:
        descriptionField = TextFormField(
          controller: item.descriptionController,
          decoration: _compactDec.copyWith(
            hintText: item.kind == QuoteItemKind.hours
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
