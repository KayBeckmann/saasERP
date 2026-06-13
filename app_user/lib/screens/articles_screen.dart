import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../services/api_client.dart';
import '../state/auth_controller.dart';
import 'price_import_screen.dart';

/// Artikelliste des aktuellen Mandanten — Freitext-first: nur `name` ist
/// Pflicht, alle anderen Felder sind optional.
class ArticlesScreen extends StatefulWidget {
  const ArticlesScreen({super.key});

  @override
  State<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends State<ArticlesScreen> {
  late Future<List<Article>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Article>> _load() {
    final auth = context.read<AuthController>();
    return auth.apiClient.listArticles(auth.token!);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _openForm({Article? article}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _ArticleFormDialog(article: article),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(Article article) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Artikel löschen?'),
        content: Text('${article.name} wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final auth = context.read<AuthController>();
    await auth.apiClient.deleteArticle(token: auth.token!, id: article.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Artikel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'Preisimport',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PriceImportScreen()),
              );
              _reload();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Article>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          final articles = snapshot.data!;
          if (articles.isEmpty) {
            return const Center(child: Text('Noch keine Artikel angelegt.'));
          }
          return ListView.separated(
            itemCount: articles.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final article = articles[index];
              return ListTile(
                title: Text(article.name),
                subtitle: Text(
                  [
                    if (article.sku != null) 'SKU ${article.sku}',
                    if (article.salePrice != null)
                      'VK ${article.salePrice!.toStringAsFixed(2)} €',
                    if (article.unit != null) article.unit!,
                  ].join(' · '),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Löschen',
                  onPressed: () => _delete(article),
                ),
                onTap: () => _openForm(article: article),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        tooltip: 'Neuer Artikel',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Formular zum Anlegen/Bearbeiten eines Artikels. Nur `name` ist Pflicht
/// (Freitext-first-Prinzip).
class _ArticleFormDialog extends StatefulWidget {
  const _ArticleFormDialog({this.article});

  final Article? article;

  @override
  State<_ArticleFormDialog> createState() => _ArticleFormDialogState();
}

class _ArticleFormDialogState extends State<_ArticleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _skuController;
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _vatRateController;
  late final TextEditingController _notesController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.article;
    _skuController = TextEditingController(text: a?.sku ?? '');
    _nameController = TextEditingController(text: a?.name ?? '');
    _unitController = TextEditingController(text: a?.unit ?? '');
    _purchasePriceController = TextEditingController(text: a?.purchasePrice?.toString() ?? '');
    _salePriceController = TextEditingController(text: a?.salePrice?.toString() ?? '');
    _vatRateController = TextEditingController(text: (a?.vatRate ?? 19.0).toString());
    _notesController = TextEditingController(text: a?.notes ?? '');
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _unitController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _vatRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _orNull(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final purchasePrice = double.tryParse(_purchasePriceController.text.trim().replaceAll(',', '.'));
    final salePrice = double.tryParse(_salePriceController.text.trim().replaceAll(',', '.'));
    final vatRate = double.tryParse(_vatRateController.text.trim().replaceAll(',', '.')) ?? 19.0;

    final auth = context.read<AuthController>();
    try {
      if (widget.article == null) {
        await auth.apiClient.createArticle(
          token: auth.token!,
          req: CreateArticleRequest(
            sku: _orNull(_skuController.text),
            name: _nameController.text.trim(),
            unit: _orNull(_unitController.text),
            purchasePrice: purchasePrice,
            salePrice: salePrice,
            vatRate: vatRate,
            notes: _orNull(_notesController.text),
          ),
        );
      } else {
        await auth.apiClient.updateArticle(
          token: auth.token!,
          id: widget.article!.id,
          req: UpdateArticleRequest(
            sku: _orNull(_skuController.text),
            name: _nameController.text.trim(),
            unit: _orNull(_unitController.text),
            purchasePrice: purchasePrice,
            salePrice: salePrice,
            vatRate: vatRate,
            notes: _orNull(_notesController.text),
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
    final isEdit = widget.article != null;

    return AlertDialog(
      title: Text(isEdit ? 'Artikel bearbeiten' : 'Neuer Artikel'),
      content: SingleChildScrollView(
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
                decoration: const InputDecoration(labelText: 'SKU / Artikelnummer'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(labelText: 'Einheit (z. B. Stück, kg, m)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _purchasePriceController,
                decoration: const InputDecoration(labelText: 'Einkaufspreis (€)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _salePriceController,
                decoration: const InputDecoration(labelText: 'Verkaufspreis (€)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _vatRateController,
                decoration: const InputDecoration(labelText: 'MwSt.-Satz (%)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notizen'),
                maxLines: 2,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
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
}
