/// Art einer Auftragsposition.
enum OrderItemKind {
  text,
  article,
  product,
  hours;

  String toJson() => name;

  static OrderItemKind fromJson(String value) => OrderItemKind.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () => OrderItemKind.text,
      );
}

/// Status eines Auftrags im Workflow `open -> in_progress -> completed/cancelled`.
enum OrderStatus {
  open,
  inProgress,
  completed,
  cancelled;

  String toJson() => switch (this) {
        OrderStatus.open => 'open',
        OrderStatus.inProgress => 'in_progress',
        OrderStatus.completed => 'completed',
        OrderStatus.cancelled => 'cancelled',
      };

  static OrderStatus fromJson(String value) => switch (value) {
        'in_progress' => OrderStatus.inProgress,
        'completed' => OrderStatus.completed,
        'cancelled' => OrderStatus.cancelled,
        _ => OrderStatus.open,
      };
}

/// Position eines Auftrags. `unitPrice`/`vatRate` sind Schnappschüsse zum
/// Anlagezeitpunkt — spätere Preisänderungen an Artikel/Produkt wirken
/// nicht nachträglich auf bestehende Aufträge.
class OrderItem {
  const OrderItem({
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
  final OrderItemKind kind;
  final String? articleId;
  final String? productId;
  final String description;
  final double quantity;
  final String? unit;
  final double unitPrice;
  final double vatRate;

  /// Optionale Gruppenbezeichnung für Zwischensummen (z. B.
  /// "Elektroinstallation"). Positionen mit gleichem Label werden im
  /// Auftrag als Gruppe mit eigener Zwischensumme dargestellt.
  final String? groupLabel;

  double get totalNet => quantity * unitPrice;

  double get totalGross => totalNet * (1 + vatRate / 100);

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json['id'] as String?,
        kind: OrderItemKind.fromJson(json['kind'] as String),
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

/// Zwischensumme einer Gruppe von Auftragspositionen mit gleichem
/// [OrderItem.groupLabel]. `label == null` fasst alle Positionen ohne
/// Gruppenzuordnung zusammen.
class OrderGroupSummary {
  const OrderGroupSummary({this.label, required this.items});

  final String? label;
  final List<OrderItem> items;

  double get totalNet => items.fold(0, (sum, item) => sum + item.totalNet);

  double get totalGross => items.fold(0, (sum, item) => sum + item.totalGross);
}

/// Auftrag eines Mandanten für einen Kunden — `orderNumber` wird über den
/// Nummernkreis "order" (Prefix "AU") vergeben. Optional aus einem Angebot
/// erzeugt (`quoteId`).
class Order {
  const Order({
    required this.id,
    required this.tenantId,
    required this.orderNumber,
    this.quoteId,
    this.customerId,
    required this.title,
    this.status = OrderStatus.open,
    this.notes,
    required this.createdAt,
    this.items = const [],
  });

  final String id;
  final String tenantId;
  final String orderNumber;
  final String? quoteId;
  final String? customerId;
  final String title;
  final OrderStatus status;
  final String? notes;
  final DateTime createdAt;
  final List<OrderItem> items;

  double get totalNet => items.fold(0, (sum, item) => sum + item.totalNet);

  double get totalGross => items.fold(0, (sum, item) => sum + item.totalGross);

  /// Positionen gruppiert nach [OrderItem.groupLabel] — Reihenfolge der
  /// Gruppen ergibt sich aus dem ersten Auftreten des Labels in [items].
  /// Ungruppierte Positionen (`groupLabel == null`) bilden eine
  /// abschließende Gruppe mit `label == null`.
  List<OrderGroupSummary> get groupedItems {
    final byLabel = <String, List<OrderItem>>{};
    final order = <String>[];
    final ungrouped = <OrderItem>[];

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
      for (final label in order) OrderGroupSummary(label: label, items: byLabel[label]!),
    ];
    if (ungrouped.isNotEmpty) {
      result.add(OrderGroupSummary(items: ungrouped));
    }
    return result;
  }

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        orderNumber: json['order_number'] as String,
        quoteId: json['quote_id'] as String?,
        customerId: json['customer_id'] as String?,
        title: json['title'] as String,
        status: OrderStatus.fromJson(json['status'] as String),
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        items: (json['items'] as List? ?? [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'order_number': orderNumber,
        'quote_id': quoteId,
        'customer_id': customerId,
        'title': title,
        'status': status.toJson(),
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
      };
}

/// Legt einen neuen Auftrag an — `order_number` wird serverseitig vergeben.
class CreateOrderRequest {
  const CreateOrderRequest({
    this.customerId,
    required this.title,
    this.notes,
    this.items = const [],
  });

  final String? customerId;
  final String title;
  final String? notes;
  final List<OrderItem> items;

  factory CreateOrderRequest.fromJson(Map<String, dynamic> json) => CreateOrderRequest(
        customerId: json['customer_id'] as String?,
        title: json['title'] as String,
        notes: json['notes'] as String?,
        items: (json['items'] as List? ?? [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'title': title,
        'notes': notes,
        'items': items.map((item) => item.toJson()).toList(),
      };
}

/// Aktualisiert einen Auftrag — `order_number` und `quote_id` bleiben
/// unverändert.
class UpdateOrderRequest {
  const UpdateOrderRequest({
    this.customerId,
    required this.title,
    this.status = OrderStatus.open,
    this.notes,
    this.items = const [],
  });

  final String? customerId;
  final String title;
  final OrderStatus status;
  final String? notes;
  final List<OrderItem> items;

  factory UpdateOrderRequest.fromJson(Map<String, dynamic> json) => UpdateOrderRequest(
        customerId: json['customer_id'] as String?,
        title: json['title'] as String,
        status: OrderStatus.fromJson(json['status'] as String),
        notes: json['notes'] as String?,
        items: (json['items'] as List? ?? [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'title': title,
        'status': status.toJson(),
        'notes': notes,
        'items': items.map((item) => item.toJson()).toList(),
      };
}
