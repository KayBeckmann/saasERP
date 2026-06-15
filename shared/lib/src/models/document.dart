/// Wer ein Dokument hochgeladen hat — Endkunde im Kundenportal oder Mandant
/// in der User-App.
enum DocumentUploader {
  customer,
  tenant;

  String toJson() => name;

  static DocumentUploader fromJson(String value) => DocumentUploader.values.firstWhere(
        (uploader) => uploader.name == value,
        orElse: () => DocumentUploader.customer,
      );
}

/// Metadaten eines Dokuments ohne Dateiinhalt — für Listenansichten der
/// mandantenfähigen Dokumentenablage (Fotos, Pläne, Vollmachten je Kunde).
class DocumentSummary {
  const DocumentSummary({
    required this.id,
    required this.tenantId,
    required this.customerId,
    required this.filename,
    required this.contentType,
    required this.sizeBytes,
    this.description,
    this.uploadedBy = DocumentUploader.customer,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String customerId;
  final String filename;
  final String contentType;
  final int sizeBytes;
  final String? description;
  final DocumentUploader uploadedBy;
  final DateTime createdAt;

  factory DocumentSummary.fromJson(Map<String, dynamic> json) => DocumentSummary(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        customerId: json['customer_id'] as String,
        filename: json['filename'] as String,
        contentType: json['content_type'] as String,
        sizeBytes: json['size_bytes'] as int,
        description: json['description'] as String?,
        uploadedBy: DocumentUploader.fromJson(json['uploaded_by'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'customer_id': customerId,
        'filename': filename,
        'content_type': contentType,
        'size_bytes': sizeBytes,
        'description': description,
        'uploaded_by': uploadedBy.toJson(),
        'created_at': createdAt.toIso8601String(),
      };
}

/// Neues Dokument hochladen — `content` wird als Base64 übertragen, da das
/// Backend Dateien als BYTEA in Postgres ablegt (kein externer
/// Objektspeicher).
class CreateDocumentRequest {
  const CreateDocumentRequest({
    required this.filename,
    required this.contentType,
    required this.contentBase64,
    this.description,
  });

  final String filename;
  final String contentType;
  final String contentBase64;
  final String? description;

  factory CreateDocumentRequest.fromJson(Map<String, dynamic> json) => CreateDocumentRequest(
        filename: json['filename'] as String,
        contentType: json['content_type'] as String,
        contentBase64: json['content_base64'] as String,
        description: json['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'content_type': contentType,
        'content_base64': contentBase64,
        'description': description,
      };
}
