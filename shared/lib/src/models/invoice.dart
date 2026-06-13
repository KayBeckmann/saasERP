/// Art einer Rechnungsposition.
enum InvoiceItemKind {
  text,
  article,
  product,
  hours;

  String toJson() => name;

  static InvoiceItemKind fromJson(String value) => InvoiceItemKind.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () => InvoiceItemKind.text,
      );
}

/// Art einer Rechnung: normale Rechnung, Teilrechnung (deckt einen Teil der
/// Auftragspositionen ab), Abschlagsrechnung (Vorauszahlung) oder
/// Schlussrechnung (rechnet die verbleibenden Positionen ab und zieht
/// [Invoice.priorInvoicedTotal] als Vorleistung ab).
enum InvoiceType {
  standard,
  partial,
  downPayment,
  closingInvoice;

  String toJson() => switch (this) {
        InvoiceType.standard => 'standard',
        InvoiceType.partial => 'partial',
        InvoiceType.downPayment => 'down_payment',
        InvoiceType.closingInvoice => 'final',
      };

  static InvoiceType fromJson(String value) => switch (value) {
        'partial' => InvoiceType.partial,
        'down_payment' => InvoiceType.downPayment,
        'final' => InvoiceType.closingInvoice,
        _ => InvoiceType.standard,
      };
}

/// Status einer Rechnung im Workflow `draft -> sent -> paid/overdue/cancelled`.
enum InvoiceStatus {
  draft,
  sent,
  paid,
  overdue,
  cancelled;

  String toJson() => name;

  static InvoiceStatus fromJson(String value) => InvoiceStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => InvoiceStatus.draft,
      );
}

/// Position einer Rechnung. `unitPrice`/`vatRate` sind Schnappschüsse zum
/// Anlagezeitpunkt — spätere Preisänderungen an Artikel/Produkt wirken
/// nicht nachträglich auf bestehende Rechnungen.
class InvoiceItem {
  const InvoiceItem({
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
    this.orderItemId,
  });

  final String? id;
  final InvoiceItemKind kind;
  final String? articleId;
  final String? productId;
  final String description;
  final double quantity;
  final String? unit;
  final double unitPrice;
  final double vatRate;

  /// Optionale Gruppenbezeichnung für Zwischensummen (z. B.
  /// "Elektroinstallation"). Positionen mit gleichem Label werden in der
  /// Rechnung als Gruppe mit eigener Zwischensumme dargestellt.
  final String? groupLabel;

  /// Verweist auf die Auftragsposition (`order_items.id`), aus der diese
  /// Rechnungsposition übernommen wurde — Grundlage für den
  /// Doppelabrechnungsschutz bei Teil-/Abschlags-/Schlussrechnungen.
  final String? orderItemId;

  double get totalNet => quantity * unitPrice;

  double get totalGross => totalNet * (1 + vatRate / 100);

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
        id: json['id'] as String?,
        kind: InvoiceItemKind.fromJson(json['kind'] as String),
        articleId: json['article_id'] as String?,
        productId: json['product_id'] as String?,
        description: json['description'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'] as String?,
        unitPrice: (json['unit_price'] as num).toDouble(),
        vatRate: (json['vat_rate'] as num).toDouble(),
        groupLabel: json['group_label'] as String?,
        orderItemId: json['order_item_id'] as String?,
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
        'order_item_id': orderItemId,
      };
}

/// Zwischensumme einer Gruppe von Rechnungspositionen mit gleichem
/// [InvoiceItem.groupLabel]. `label == null` fasst alle Positionen ohne
/// Gruppenzuordnung zusammen.
class InvoiceGroupSummary {
  const InvoiceGroupSummary({this.label, required this.items});

  final String? label;
  final List<InvoiceItem> items;

  double get totalNet => items.fold(0, (sum, item) => sum + item.totalNet);

  double get totalGross => items.fold(0, (sum, item) => sum + item.totalGross);
}

/// Rechnung eines Mandanten an einen Kunden — `invoiceNumber` wird über den
/// Nummernkreis "invoice" (Prefix "R") vergeben. Optional aus einem Auftrag
/// erzeugt (`orderId`).
class Invoice {
  const Invoice({
    required this.id,
    required this.tenantId,
    required this.invoiceNumber,
    this.orderId,
    this.customerId,
    required this.title,
    this.status = InvoiceStatus.draft,
    this.dueDate,
    this.notes,
    required this.createdAt,
    this.items = const [],
    this.invoiceType = InvoiceType.standard,
    this.priorInvoicedTotal,
  });

  final String id;
  final String tenantId;
  final String invoiceNumber;
  final String? orderId;
  final String? customerId;
  final String title;
  final InvoiceStatus status;
  final DateTime? dueDate;
  final String? notes;
  final DateTime createdAt;
  final List<InvoiceItem> items;

  /// Rechnungsart (Rechnung/Teilrechnung/Abschlagsrechnung/Schlussrechnung).
  final InvoiceType invoiceType;

  /// Nur bei [InvoiceType.closingInvoice]: Summe der Bruttobeträge aller
  /// vorherigen, nicht-stornierten Rechnungen desselben Auftrags.
  final double? priorInvoicedTotal;

  double get totalNet => items.fold(0, (sum, item) => sum + item.totalNet);

  double get totalGross => items.fold(0, (sum, item) => sum + item.totalGross);

  /// Brutto-Betrag abzüglich bereits gestellter Vorleistungen
  /// ([priorInvoicedTotal]) — bei allen Rechnungstypen außer
  /// [InvoiceType.closingInvoice] identisch zu [totalGross].
  double get amountDue => totalGross - (priorInvoicedTotal ?? 0);

  /// Positionen gruppiert nach [InvoiceItem.groupLabel] — Reihenfolge der
  /// Gruppen ergibt sich aus dem ersten Auftreten des Labels in [items].
  /// Ungruppierte Positionen (`groupLabel == null`) bilden eine
  /// abschließende Gruppe mit `label == null`.
  List<InvoiceGroupSummary> get groupedItems {
    final byLabel = <String, List<InvoiceItem>>{};
    final order = <String>[];
    final ungrouped = <InvoiceItem>[];

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
      for (final label in order) InvoiceGroupSummary(label: label, items: byLabel[label]!),
    ];
    if (ungrouped.isNotEmpty) {
      result.add(InvoiceGroupSummary(items: ungrouped));
    }
    return result;
  }

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        invoiceNumber: json['invoice_number'] as String,
        orderId: json['order_id'] as String?,
        customerId: json['customer_id'] as String?,
        title: json['title'] as String,
        status: InvoiceStatus.fromJson(json['status'] as String),
        dueDate: json['due_date'] == null ? null : DateTime.parse(json['due_date'] as String),
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        items: (json['items'] as List? ?? [])
            .map((e) => InvoiceItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        invoiceType: InvoiceType.fromJson(json['invoice_type'] as String? ?? 'standard'),
        priorInvoicedTotal: (json['prior_invoiced_total'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'invoice_number': invoiceNumber,
        'order_id': orderId,
        'customer_id': customerId,
        'title': title,
        'status': status.toJson(),
        'due_date': dueDate?.toIso8601String().split('T').first,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
        'invoice_type': invoiceType.toJson(),
        'prior_invoiced_total': priorInvoicedTotal,
      };
}

/// Legt eine neue Rechnung an — `invoice_number` wird serverseitig vergeben.
class CreateInvoiceRequest {
  const CreateInvoiceRequest({
    this.customerId,
    required this.title,
    this.dueDate,
    this.notes,
    this.items = const [],
    this.invoiceType = InvoiceType.standard,
    this.priorInvoicedTotal,
  });

  final String? customerId;
  final String title;
  final DateTime? dueDate;
  final String? notes;
  final List<InvoiceItem> items;
  final InvoiceType invoiceType;
  final double? priorInvoicedTotal;

  factory CreateInvoiceRequest.fromJson(Map<String, dynamic> json) => CreateInvoiceRequest(
        customerId: json['customer_id'] as String?,
        title: json['title'] as String,
        dueDate: json['due_date'] == null ? null : DateTime.parse(json['due_date'] as String),
        notes: json['notes'] as String?,
        items: (json['items'] as List? ?? [])
            .map((e) => InvoiceItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        invoiceType: InvoiceType.fromJson(json['invoice_type'] as String? ?? 'standard'),
        priorInvoicedTotal: (json['prior_invoiced_total'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'title': title,
        'due_date': dueDate?.toIso8601String().split('T').first,
        'notes': notes,
        'items': items.map((item) => item.toJson()).toList(),
        'invoice_type': invoiceType.toJson(),
        'prior_invoiced_total': priorInvoicedTotal,
      };
}

/// Aktualisiert eine Rechnung — `invoice_number` und `order_id` bleiben
/// unverändert.
class UpdateInvoiceRequest {
  const UpdateInvoiceRequest({
    this.customerId,
    required this.title,
    this.status = InvoiceStatus.draft,
    this.dueDate,
    this.notes,
    this.items = const [],
    this.invoiceType = InvoiceType.standard,
    this.priorInvoicedTotal,
  });

  final String? customerId;
  final String title;
  final InvoiceStatus status;
  final DateTime? dueDate;
  final String? notes;
  final List<InvoiceItem> items;
  final InvoiceType invoiceType;
  final double? priorInvoicedTotal;

  factory UpdateInvoiceRequest.fromJson(Map<String, dynamic> json) => UpdateInvoiceRequest(
        customerId: json['customer_id'] as String?,
        title: json['title'] as String,
        status: InvoiceStatus.fromJson(json['status'] as String),
        dueDate: json['due_date'] == null ? null : DateTime.parse(json['due_date'] as String),
        notes: json['notes'] as String?,
        items: (json['items'] as List? ?? [])
            .map((e) => InvoiceItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        invoiceType: InvoiceType.fromJson(json['invoice_type'] as String? ?? 'standard'),
        priorInvoicedTotal: (json['prior_invoiced_total'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'title': title,
        'status': status.toJson(),
        'due_date': dueDate?.toIso8601String().split('T').first,
        'notes': notes,
        'invoice_type': invoiceType.toJson(),
        'prior_invoiced_total': priorInvoicedTotal,
        'items': items.map((item) => item.toJson()).toList(),
      };
}
