/// Art einer Angebotsposition.
enum QuoteItemKind {
  text,
  article,
  product,
  hours;

  String toJson() => name;

  static QuoteItemKind fromJson(String value) => QuoteItemKind.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () => QuoteItemKind.text,
      );
}

/// Status eines Angebots im Workflow `draft -> sent -> accepted/rejected`.
enum QuoteStatus {
  draft,
  sent,
  accepted,
  rejected;

  String toJson() => name;

  static QuoteStatus fromJson(String value) => QuoteStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => QuoteStatus.draft,
      );
}

/// Position eines Angebots. `unitPrice`/`vatRate` sind Schnappschüsse zum
/// Anlagezeitpunkt — spätere Preisänderungen an Artikel/Produkt wirken
/// nicht nachträglich auf bestehende Angebote.
class QuoteItem {
  const QuoteItem({
    this.id,
    required this.kind,
    this.articleId,
    this.productId,
    required this.description,
    this.quantity = 1,
    this.unit,
    this.unitPrice = 0,
    this.vatRate = 19.0,
    this.groupLabel,
  });

  final String? id;
  final QuoteItemKind kind;
  final String? articleId;
  final String? productId;
  final String description;
  final double quantity;
  final String? unit;
  final double unitPrice;
  final double vatRate;

  /// Optionale Gruppenbezeichnung für Zwischensummen (z. B.
  /// "Elektroinstallation"). Positionen mit gleichem Label werden im
  /// Angebot als Gruppe mit eigener Zwischensumme dargestellt.
  final String? groupLabel;

  double get totalNet => quantity * unitPrice;

  double get totalGross => totalNet * (1 + vatRate / 100);

  factory QuoteItem.fromJson(Map<String, dynamic> json) => QuoteItem(
        id: json['id'] as String?,
        kind: QuoteItemKind.fromJson(json['kind'] as String),
        articleId: json['article_id'] as String?,
        productId: json['product_id'] as String?,
        description: json['description'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'] as String?,
        unitPrice: (json['unit_price'] as num).toDouble(),
        vatRate: (json['vat_rate'] as num).toDouble(),
        groupLabel: json['group_label'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'kind': kind.toJson(),
        'article_id': articleId,
        'product_id': productId,
        'description': description,
        'quantity': quantity,
        'unit': unit,
        'unit_price': unitPrice,
        'vat_rate': vatRate,
        'group_label': groupLabel,
      };
}

/// Zwischensumme einer Gruppe von Angebotspositionen mit gleichem
/// [QuoteItem.groupLabel]. `label == null` fasst alle Positionen ohne
/// Gruppenzuordnung zusammen.
class QuoteGroupSummary {
  const QuoteGroupSummary({this.label, required this.items});

  final String? label;
  final List<QuoteItem> items;

  double get totalNet => items.fold(0, (sum, item) => sum + item.totalNet);

  double get totalGross => items.fold(0, (sum, item) => sum + item.totalGross);
}

/// Angebot eines Mandanten an einen Kunden — `quoteNumber` wird über den
/// Nummernkreis "quote" (Prefix "A") vergeben.
class Quote {
  const Quote({
    required this.id,
    required this.tenantId,
    required this.quoteNumber,
    this.customerId,
    required this.title,
    this.status = QuoteStatus.draft,
    this.validUntil,
    this.notes,
    required this.createdAt,
    this.items = const [],
    this.customerDecisionAt,
    this.customerComment,
  });

  final String id;
  final String tenantId;
  final String quoteNumber;
  final String? customerId;
  final String title;
  final QuoteStatus status;
  final DateTime? validUntil;
  final String? notes;
  final DateTime createdAt;
  final List<QuoteItem> items;

  /// Zeitpunkt, zu dem der Endkunde im Kundenportal über das Angebot
  /// entschieden hat (Status `accepted`/`rejected`) — `null`, solange keine
  /// Entscheidung vorliegt.
  final DateTime? customerDecisionAt;

  /// Optionaler Kommentar des Endkunden zu seiner Entscheidung.
  final String? customerComment;

  double get totalNet => items.fold(0, (sum, item) => sum + item.totalNet);

  double get totalGross => items.fold(0, (sum, item) => sum + item.totalGross);

  /// Positionen gruppiert nach [QuoteItem.groupLabel] — Reihenfolge der
  /// Gruppen ergibt sich aus dem ersten Auftreten des Labels in [items].
  /// Ungruppierte Positionen (`groupLabel == null`) bilden eine
  /// abschließende Gruppe mit `label == null`.
  List<QuoteGroupSummary> get groupedItems {
    final byLabel = <String, List<QuoteItem>>{};
    final order = <String>[];
    final ungrouped = <QuoteItem>[];

    for (final item in items) {
      final label = item.groupLabel;
      if (label == null || label.trim().isEmpty) {
        ungrouped.add(item);
        continue;
      }
      if (!byLabel.containsKey(label)) {
        byLabel[label] = [];
        order.add(label);
      }
      byLabel[label]!.add(item);
    }

    final result = [
      for (final label in order) QuoteGroupSummary(label: label, items: byLabel[label]!),
    ];
    if (ungrouped.isNotEmpty) {
      result.add(QuoteGroupSummary(items: ungrouped));
    }
    return result;
  }

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        quoteNumber: json['quote_number'] as String,
        customerId: json['customer_id'] as String?,
        title: json['title'] as String,
        status: QuoteStatus.fromJson(json['status'] as String),
        validUntil: json['valid_until'] == null ? null : DateTime.parse(json['valid_until'] as String),
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        items: (json['items'] as List? ?? [])
            .map((e) => QuoteItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        customerDecisionAt:
            json['customer_decision_at'] == null ? null : DateTime.parse(json['customer_decision_at'] as String),
        customerComment: json['customer_comment'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'quote_number': quoteNumber,
        'customer_id': customerId,
        'title': title,
        'status': status.toJson(),
        'valid_until': validUntil?.toIso8601String().split('T').first,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
        'customer_decision_at': customerDecisionAt?.toIso8601String(),
        'customer_comment': customerComment,
      };
}

/// Legt ein neues Angebot an — `quote_number` wird serverseitig vergeben.
class CreateQuoteRequest {
  const CreateQuoteRequest({
    this.customerId,
    required this.title,
    this.validUntil,
    this.notes,
    this.items = const [],
  });

  final String? customerId;
  final String title;
  final DateTime? validUntil;
  final String? notes;
  final List<QuoteItem> items;

  factory CreateQuoteRequest.fromJson(Map<String, dynamic> json) => CreateQuoteRequest(
        customerId: json['customer_id'] as String?,
        title: json['title'] as String,
        validUntil: json['valid_until'] == null ? null : DateTime.parse(json['valid_until'] as String),
        notes: json['notes'] as String?,
        items: (json['items'] as List? ?? [])
            .map((e) => QuoteItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'title': title,
        'valid_until': validUntil?.toIso8601String().split('T').first,
        'notes': notes,
        'items': items.map((item) => item.toJson()).toList(),
      };
}

/// Aktualisiert ein Angebot — `quote_number` bleibt unverändert.
class UpdateQuoteRequest {
  const UpdateQuoteRequest({
    this.customerId,
    required this.title,
    this.status = QuoteStatus.draft,
    this.validUntil,
    this.notes,
    this.items = const [],
  });

  final String? customerId;
  final String title;
  final QuoteStatus status;
  final DateTime? validUntil;
  final String? notes;
  final List<QuoteItem> items;

  factory UpdateQuoteRequest.fromJson(Map<String, dynamic> json) => UpdateQuoteRequest(
        customerId: json['customer_id'] as String?,
        title: json['title'] as String,
        status: QuoteStatus.fromJson(json['status'] as String),
        validUntil: json['valid_until'] == null ? null : DateTime.parse(json['valid_until'] as String),
        notes: json['notes'] as String?,
        items: (json['items'] as List? ?? [])
            .map((e) => QuoteItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'title': title,
        'status': status.toJson(),
        'valid_until': validUntil?.toIso8601String().split('T').first,
        'notes': notes,
        'items': items.map((item) => item.toJson()).toList(),
      };
}

/// Entscheidung des Endkunden zu einem versendeten Angebot im Kundenportal
/// (`app_kunde`) — `decision` muss `accepted` oder `rejected` sein,
/// `comment` ist optional.
class CustomerQuoteDecisionRequest {
  const CustomerQuoteDecisionRequest({required this.decision, this.comment});

  final QuoteStatus decision;
  final String? comment;

  factory CustomerQuoteDecisionRequest.fromJson(Map<String, dynamic> json) => CustomerQuoteDecisionRequest(
        decision: QuoteStatus.fromJson(json['decision'] as String),
        comment: json['comment'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'decision': decision.toJson(),
        if (comment != null) 'comment': comment,
      };
}
