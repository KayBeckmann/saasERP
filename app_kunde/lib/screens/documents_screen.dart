import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../formatting.dart';
import '../state/auth_controller.dart';

/// Mandantenfähige Dokumentenablage im Kundenportal: Der Endkunde kann
/// eigene Dateien (Fotos, Pläne, Vollmachten) hochladen, ansehen, herunter-
/// laden und löschen.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late Future<List<DocumentSummary>> _future;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DocumentSummary>> _load() {
    final auth = context.read<AuthController>();
    return auth.apiClient.listDocuments(auth.token!);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final files = result?.files ?? const <PlatformFile>[];
    if (files.isEmpty || files.first.bytes == null) return;
    final file = files.first;
    if (!mounted) return;

    final description = await showDialog<String>(
      context: context,
      builder: (context) => _DescriptionDialog(filename: file.name),
    );
    if (description == null) return;
    if (!mounted) return;

    final auth = context.read<AuthController>();
    setState(() => _uploading = true);
    try {
      await auth.apiClient.uploadDocument(
        token: auth.token!,
        filename: file.name,
        contentType: _contentTypeFor(file.name),
        content: file.bytes!,
        description: description.trim().isEmpty ? null : description.trim(),
      );
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Hochladen: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _view(DocumentSummary document) async {
    final auth = context.read<AuthController>();
    try {
      final bytes = await auth.apiClient.getDocument(token: auth.token!, documentId: document.id);
      if (!mounted) return;

      if (document.contentType == 'application/pdf') {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: document.filename);
        return;
      }
      if (document.contentType.startsWith('image/')) {
        await showDialog<void>(
          context: context,
          builder: (context) => Dialog(child: InteractiveViewer(child: Image.memory(bytes))),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vorschau für diesen Dateityp wird nicht unterstützt.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  Future<void> _delete(DocumentSummary document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dokument löschen?'),
        content: Text('"${document.filename}" wirklich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final auth = context.read<AuthController>();
    try {
      await auth.apiClient.deleteDocument(token: auth.token!, documentId: document.id);
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dokumente')),
      body: FutureBuilder<List<DocumentSummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler beim Laden: ${snapshot.error}'));
          }

          final documents = snapshot.data!;
          if (documents.isEmpty) {
            return const Center(child: Text('Noch keine Dokumente hochgeladen.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final document = documents[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(document.filename),
                  subtitle: Text(
                    [
                      formatFileSize(document.sizeBytes),
                      formatDate(document.createdAt),
                      if (document.description != null && document.description!.trim().isNotEmpty)
                        document.description!,
                    ].join(' · '),
                  ),
                  onTap: () => _view(document),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Löschen',
                    onPressed: () => _delete(document),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploading ? null : _upload,
        tooltip: 'Dokument hochladen',
        child: _uploading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.upload_file),
      ),
    );
  }
}

/// Bekannte Dateiendungen → MIME-Type. Fällt auf `application/octet-stream`
/// zurück, wenn die Endung unbekannt ist.
String _contentTypeFor(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  return switch (ext) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'txt' => 'text/plain',
    _ => 'application/octet-stream',
  };
}

/// Optionale Beschreibung vor dem Hochladen einer Datei.
class _DescriptionDialog extends StatefulWidget {
  const _DescriptionDialog({required this.filename});

  final String filename;

  @override
  State<_DescriptionDialog> createState() => _DescriptionDialogState();
}

class _DescriptionDialogState extends State<_DescriptionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.filename),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(labelText: 'Beschreibung (optional)'),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: const Text('Hochladen')),
      ],
    );
  }
}
