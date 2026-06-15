import 'dart:typed_data';

import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

/// Mandantenfähige Dokumentenablage (Fotos, Pläne, Vollmachten) je Kunde —
/// Dateien werden als BYTEA in Postgres abgelegt (M2b-Erweiterung, kein
/// externer Objektspeicher).
class DocumentRepository {
  DocumentRepository(this._pool);

  final Pool<void> _pool;

  static const _summaryColumns =
      'id, tenant_id, customer_id, filename, content_type, size_bytes, description, uploaded_by, created_at';

  Future<DocumentSummary> create({
    required String tenantId,
    required String customerId,
    required String filename,
    required String contentType,
    required Uint8List content,
    String? description,
    DocumentUploader uploadedBy = DocumentUploader.customer,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'INSERT INTO documents '
        '(tenant_id, customer_id, filename, content_type, size_bytes, content, description, uploaded_by) '
        'VALUES (@tenant_id, @customer_id, @filename, @content_type, @size_bytes, @content, @description, @uploaded_by) '
        'RETURNING $_summaryColumns',
      ),
      parameters: {
        'tenant_id': tenantId,
        'customer_id': customerId,
        'filename': filename,
        'content_type': contentType,
        'size_bytes': content.length,
        'content': content,
        'description': description,
        'uploaded_by': uploadedBy.toJson(),
      },
    );
    return _summaryFromRow(result.first.toColumnMap());
  }

  /// Dokumente eines Kunden — für Kundenportal und User-App.
  Future<List<DocumentSummary>> listForCustomer({required String tenantId, required String customerId}) async {
    final result = await _pool.execute(
      Sql.named(
        'SELECT $_summaryColumns FROM documents '
        'WHERE tenant_id = @tenant_id AND customer_id = @customer_id ORDER BY created_at DESC',
      ),
      parameters: {'tenant_id': tenantId, 'customer_id': customerId},
    );
    return result.map((row) => _summaryFromRow(row.toColumnMap())).toList();
  }

  Future<DocumentSummary?> findSummaryById({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_summaryColumns FROM documents WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    if (result.isEmpty) return null;
    return _summaryFromRow(result.first.toColumnMap());
  }

  /// Metadaten + Dateiinhalt für den Download. `null`, falls kein Dokument
  /// mit dieser ID für diesen Mandanten existiert.
  Future<(DocumentSummary, Uint8List)?> findContentById({required String tenantId, required String id}) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_summaryColumns, content FROM documents WHERE tenant_id = @tenant_id AND id = @id'),
      parameters: {'tenant_id': tenantId, 'id': id},
    );
    if (result.isEmpty) return null;
    final row = result.first.toColumnMap();
    return (_summaryFromRow(row), row['content'] as Uint8List);
  }

  /// Löscht ein Dokument. Mit [customerId] zusätzlich darauf eingeschränkt,
  /// damit Endkunden im Kundenportal nur eigene Dokumente löschen können.
  Future<bool> delete({required String tenantId, required String id, String? customerId}) async {
    final result = await _pool.execute(
      Sql.named(
        'DELETE FROM documents WHERE tenant_id = @tenant_id AND id = @id'
        '${customerId != null ? ' AND customer_id = @customer_id' : ''}',
      ),
      parameters: {
        'tenant_id': tenantId,
        'id': id,
        if (customerId != null) 'customer_id': customerId,
      },
    );
    return result.affectedRows > 0;
  }

  DocumentSummary _summaryFromRow(Map<String, dynamic> row) => DocumentSummary(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String,
        customerId: row['customer_id'] as String,
        filename: row['filename'] as String,
        contentType: row['content_type'] as String,
        sizeBytes: row['size_bytes'] as int,
        description: row['description'] as String?,
        uploadedBy: DocumentUploader.fromJson(row['uploaded_by'] as String),
        createdAt: (row['created_at'] as DateTime).toUtc(),
      );
}
