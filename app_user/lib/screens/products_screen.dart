import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import '../widgets/app_data_table.dart';
import '../widgets/app_shell.dart';

/// Produktliste des aktuellen Mandanten — Bundles aus Artikeln und/oder
/// Arbeitszeit mit eigenem Verkaufspreis (Freitext-first: nur `name` ist
/// Pflicht).
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late Future<({List<Product> products, List<Article> articles})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({List<Product> products, List<Article> articles})> _load() async {
    final auth = context.read<AuthController>();
    final products = await auth.apiClient.listProducts(auth.token!);
    final articles = await auth.apiClient.listArticles(auth.token!);
    return (products: products, articles: articles);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _openForm({Product? product, required List<Article> articles}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _ProductFormDialog(product: product, articles: articles),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Produkt löschen?'),
        content: Text('${product.name} wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final auth = context.read<AuthController>();
    await auth.apiClient.deleteProduct(token: auth.token!, id: product.id);
    _reload();
  }

  Future<void> _confirmPrice(Product product) async {
    final auth = context.read<AuthController>();
    await auth.apiClient.confirmProductPrice(token: auth.token!, id: product.id);
    _reload();
  }

  Future<void> _rejectPrice(Product product) async {
    final auth = context.read<AuthController>();
    await auth.apiClient.rejectProductPrice(token: auth.token!, id: product.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentItem: AppNavItem.products,
      title: 'Produkte',
      body: FutureBuilder<({List<Product> products, List<Article> articles})>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final products = snapshot.data!.products;
          final articles = snapshot.data!.articles;
          return AppDataTable(
            emptyLabel: articles.isEmpty
                ? 'Noch keine Produkte angelegt. Lege zuerst Artikel im Artikelstamm an, um sie als Positionen zu verwenden.'
                : 'Noch keine Produkte angelegt.',
            columns: const [
              AppDataColumn('Name', flex: 3),
              AppDataColumn('Verkaufspreis', numeric: true, flex: 2),
              AppDataColumn('Kosten', numeric: true, flex: 2),
              AppDataColumn('Positionen', numeric: true, flex: 1),
            ],
            rows: [
              for (final product in products)
                AppDataRow(
                  onTap: () => _openForm(product: product, articles: articles),
                  cells: [
                    Text(product.name),
                    _PriceCell(product: product, onConfirm: _confirmPrice, onReject: _rejectPrice),
                    Text('${product.totalCost.toStringAsFixed(2)} €'),
                    Text('${product.components.length}'),
                  ],
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Löschen',
                    onPressed: () => _delete(product),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FutureBuilder<({List<Product> products, List<Article> articles})>(
        future: _future,
        builder: (context, snapshot) {
          final articles = snapshot.data?.articles ?? [];
          return FloatingActionButton(
            onPressed: snapshot.connectionState == ConnectionState.done
                ? () => _openForm(articles: articles)
                : null,
            tooltip: 'Neues Produkt',
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}

/// Verkaufspreis eines Produkts, mit optionalem Preisvorschlag aus dem
/// Preisimport (annehmen/verwerfen).
class _PriceCell extends StatelessWidget {
  const _PriceCell({required this.product, required this.onConfirm, required this.onReject});

  final Product product;
  final void Function(Product product) onConfirm;
  final void Function(Product product) onReject;

  @override
  Widget build(BuildContext context) {
    if (product.pendingSalePrice == null) {
      return Text('${product.salePrice.toStringAsFixed(2)} €');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${product.salePrice.toStringAsFixed(2)} €'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Vorschlag ${product.pendingSalePrice!.toStringAsFixed(2)} €',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green, size: 18),
              tooltip: 'Vorschlag übernehmen',
              onPressed: () => onConfirm(product),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red, size: 18),
              tooltip: 'Vorschlag verwerfen',
              onPressed: () => onReject(product),
            ),
          ],
        ),
      ],
    );
  }
}

class _ComponentDraft {
  _ComponentDraft({
    required this.kind,
    this.articleId,
    String? label,
    double quantity = 1,
    double unitCost = 0,
  })  : labelController = TextEditingController(text: label ?? ''),
        quantityController = TextEditingController(text: quantity.toString()),
        unitCostController = TextEditingController(text: unitCost.toString());

  ProductComponentKind kind;
  String? articleId;
  final TextEditingController labelController;
  final TextEditingController quantityController;
  final TextEditingController unitCostController;

  void dispose() {
    labelController.dispose();
    quantityController.dispose();
    unitCostController.dispose();
  }

  ProductComponent toComponent() => ProductComponent(
        kind: kind,
        articleId: kind == ProductComponentKind.article ? articleId : null,
        label: kind == ProductComponentKind.labor ? labelController.text.trim() : null,
        quantity: double.tryParse(quantityController.text.trim().replaceAll(',', '.')) ?? 0,
        unitCost: double.tryParse(unitCostController.text.trim().replaceAll(',', '.')) ?? 0,
      );
}

/// Formular zum Anlegen/Bearbeiten eines Produkts inkl. Positionen.
class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({this.product, required this.articles});

  final Product? product;
  final List<Article> articles;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _skuController;
  late final TextEditingController _nameController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _vatRateController;
  late final TextEditingController _notesController;
  late final List<_ComponentDraft> _components;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _skuController = TextEditingController(text: p?.sku ?? '');
    _nameController = TextEditingController(text: p?.name ?? '');
    _salePriceController = TextEditingController(text: (p?.salePrice ?? 0).toString());
    _vatRateController = TextEditingController(text: (p?.vatRate ?? 19.0).toString());
    _notesController = TextEditingController(text: p?.notes ?? '');
    _components = (p?.components ?? [])
        .map((c) => _ComponentDraft(
              kind: c.kind,
              articleId: c.articleId,
              label: c.label,
              quantity: c.quantity,
              unitCost: c.unitCost,
            ))
        .toList();
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _salePriceController.dispose();
    _vatRateController.dispose();
    _notesController.dispose();
    for (final component in _components) {
      component.dispose();
    }
    super.dispose();
  }

  String? _orNull(String value) => value.trim().isEmpty ? null : value.trim();

  void _addArticleComponent() {
    if (widget.articles.isEmpty) return;
    final article = widget.articles.first;
    setState(() {
      _components.add(
        _ComponentDraft(
          kind: ProductComponentKind.article,
          articleId: article.id,
          quantity: 1,
          unitCost: article.purchasePrice ?? 0,
        ),
      );
    });
  }

  void _addLaborComponent() {
    setState(() {
      _components.add(
        _ComponentDraft(kind: ProductComponentKind.labor, quantity: 1, unitCost: 0),
      );
    });
  }

  void _removeComponent(int index) {
    setState(() {
      _components.removeAt(index).dispose();
    });
  }

  double get _totalCost {
    var total = 0.0;
    for (final component in _components) {
      final quantity = double.tryParse(component.quantityController.text.trim().replaceAll(',', '.')) ?? 0;
      final unitCost = double.tryParse(component.unitCostController.text.trim().replaceAll(',', '.')) ?? 0;
      total += quantity * unitCost;
    }
    return total;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final salePrice = double.tryParse(_salePriceController.text.trim().replaceAll(',', '.')) ?? 0;
    final vatRate = double.tryParse(_vatRateController.text.trim().replaceAll(',', '.')) ?? 19.0;
    final components = _components.map((c) => c.toComponent()).toList();

    final auth = context.read<AuthController>();
    try {
      if (widget.product == null) {
        await auth.apiClient.createProduct(
          token: auth.token!,
          req: CreateProductRequest(
            sku: _orNull(_skuController.text),
            name: _nameController.text.trim(),
            salePrice: salePrice,
            vatRate: vatRate,
            notes: _orNull(_notesController.text),
            components: components,
          ),
        );
      } else {
        await auth.apiClient.updateProduct(
          token: auth.token!,
          id: widget.product!.id,
          req: UpdateProductRequest(
            sku: _orNull(_skuController.text),
            name: _nameController.text.trim(),
            salePrice: salePrice,
            vatRate: vatRate,
            notes: _orNull(_notesController.text),
            components: components,
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
    final isEdit = widget.product != null;

    return AlertDialog(
      title: Text(isEdit ? 'Produkt bearbeiten' : 'Neues Produkt'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name *'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Pflichtfeld' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _skuController,
                  decoration: const InputDecoration(labelText: 'SKU / Produktnummer'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _salePriceController,
                        decoration: const InputDecoration(labelText: 'Verkaufspreis (€)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _vatRateController,
                        decoration: const InputDecoration(labelText: 'MwSt.-Satz (%)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notizen'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Positionen', style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: widget.articles.isEmpty ? null : _addArticleComponent,
                      icon: const Icon(Icons.add),
                      label: const Text('Artikel'),
                    ),
                    TextButton.icon(
                      onPressed: _addLaborComponent,
                      icon: const Icon(Icons.add),
                      label: const Text('Arbeitszeit'),
                    ),
                  ],
                ),
                for (var i = 0; i < _components.length; i++) _buildComponentRow(i),
                const SizedBox(height: 8),
                Text(
                  'Kosten gesamt: ${_totalCost.toStringAsFixed(2)} €',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Speichern'),
        ),
      ],
    );
  }

  Widget _buildComponentRow(int index) {
    final component = _components[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: component.kind == ProductComponentKind.article
                ? DropdownButtonFormField<String>(
                    initialValue: component.articleId,
                    decoration: const InputDecoration(labelText: 'Artikel'),
                    items: widget.articles
                        .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        component.articleId = value;
                        final article = widget.articles.firstWhere((a) => a.id == value);
                        component.unitCostController.text = (article.purchasePrice ?? 0).toString();
                      });
                    },
                  )
                : TextFormField(
                    controller: component.labelController,
                    decoration: const InputDecoration(labelText: 'Bezeichnung (z. B. Montage)'),
                  ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: component.quantityController,
              decoration: InputDecoration(
                labelText: component.kind == ProductComponentKind.labor ? 'Stunden' : 'Menge',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: component.unitCostController,
              decoration: InputDecoration(
                labelText: component.kind == ProductComponentKind.labor ? 'Satz (€/h)' : 'EK (€)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Position entfernen',
            onPressed: () => _removeComponent(index),
          ),
        ],
      ),
    );
  }
}
