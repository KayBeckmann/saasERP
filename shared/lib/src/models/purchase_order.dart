/// Status einer Bestellung im Workflow
/// `open -> ordered -> partially_delivered/fully_delivered`.
enum PurchaseOrderStatus {
  open,
  ordered,
  partiallyDelivered,
  fullyDelivered;

  String toJson() => switch (this) {
        PurchaseOrderStatus.open => 'open',
        PurchaseOrderStatus.ordered => 'ordered',
        PurchaseOrderStatus.partiallyDelivered => 'partially_delivered',
        PurchaseOrderStatus.fullyDelivered => 'fully_delivered',
      };

  static PurchaseOrderStatus fromJson(String value) => switch (value) {
        'ordered' => PurchaseOrderStatus.ordered,
        'partially_delivered' => PurchaseOrderStatus.partiallyDelivered,
        'fully_delivered' => PurchaseOrderStatus.fullyDelivered,
        _ => PurchaseOrderStatus.open,
      };
}

/// Eingefrorener Quellverweis einer Bestellposition auf die
/// Auftragsposition(en)/Raumgruppe(n), die zu ihr beigetragen haben
/// (Roadmap "Raumgruppen → Auftrag → Lieferantenbestellungen"). Eine
/// Bestellposition fasst dieselbe Artikel-SKU für den Einkauf zusammen,
/// kann aber mehrere Quellen haben — deshalb eine Liste statt einer
/// einzelnen Referenz. `orderItemId` kann `null` werden, wenn die
/// ursprüngliche Auftragsposition später gelöscht/ersetzt wurde
/// (Aufträge ersetzen ihre Positionen komplett bei jeder Änderung);
/// `groupLabel`/`quantity` bleiben als eingefrorene Angabe trotzdem
/// erhalten (analog zum WaaS-Rechnungs-Snapshot aus RF1).
class PurchaseOrderItemSource {
  const PurchaseOrderItemSource({
    this.orderId,
    this.orderItemId,
    this.groupLabel,
    required this.quantity,
  });

  final String? orderId;
  final String? orderItemId;
  final String? groupLabel;
  final double quantity;

  factory PurchaseOrderItemSource.fromJson(Map<String, dynamic> json) => PurchaseOrderItemSource(
        orderId: json['order_id'] as String?,
        orderItemId: json['order_item_id'] as String?,
        groupLabel: json['group_label'] as String?,
        quantity: (json['quantity'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'order_id': orderId,
        'order_item_id': orderItemId,
        'group_label': groupLabel,
        'quantity': quantity,
      };
}

/// Position einer Bestellung. `articleId` ist optional (Freitext-Position
/// möglich), `quantityDelivered` trackt den bisherigen Wareneingang.
/// `sources` ist nur bei aus einem Auftrag erzeugten Positionen gesetzt
/// (siehe [PurchaseOrderItemSource]).
class PurchaseOrderItem {
  const PurchaseOrderItem({
    this.id,
    this.articleId,
    required this.description,
    this.quantity = 1,
    this.quantityDelivered = 0,
    this.unit,
    this.unitPrice = 0,
    this.sources = const [],
  });

  final String? id;
  final String? articleId;
  final String description;
  final double quantity;
  final double quantityDelivered;
  final String? unit;
  final double unitPrice;
  final List<PurchaseOrderItemSource> sources;

  double get totalNet => quantity * unitPrice;

  bool get isFullyDelivered => quantityDelivered >= quantity;

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) => PurchaseOrderItem(
        id: json['id'] as String?,
        articleId: json['article_id'] as String?,
        description: json['description'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        quantityDelivered: (json['quantity_delivered'] as num? ?? 0).toDouble(),
        unit: json['unit'] as String?,
        unitPrice: (json['unit_price'] as num).toDouble(),
        sources: (json['sources'] as List? ?? [])
            .map((e) => PurchaseOrderItemSource.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'article_id': articleId,
        'description': description,
        'quantity': quantity,
        'quantity_delivered': quantityDelivered,
        'unit': unit,
        'unit_price': unitPrice,
        'sources': sources.map((s) => s.toJson()).toList(),
      };
}

/// Bestellung eines Mandanten bei einem Lieferanten —
/// `purchaseOrderNumber` wird über den Nummernkreis "purchase_order"
/// (Prefix "BE") vergeben. Optional aus einem Auftrag erzeugt ([orderId]).
class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.tenantId,
    required this.purchaseOrderNumber,
    this.supplierId,
    this.orderId,
    this.projectId,
    this.status = PurchaseOrderStatus.open,
    this.notes,
    required this.createdAt,
    this.items = const [],
  });

  final String id;
  final String tenantId;
  final String purchaseOrderNumber;
  final String? supplierId;
  final String? orderId;

  /// Optionale Zuordnung zu einem Projekt — Grundlage für die
  /// Ausgaben-Seite der Projekt-Gewinn/Verlust-Übersicht.
  final String? projectId;
  final PurchaseOrderStatus status;
  final String? notes;
  final DateTime createdAt;
  final List<PurchaseOrderItem> items;

  double get totalNet => items.fold(0, (sum, item) => sum + item.totalNet);

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) => PurchaseOrder(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        purchaseOrderNumber: json['purchase_order_number'] as String,
        supplierId: json['supplier_id'] as String?,
        orderId: json['order_id'] as String?,
        projectId: json['project_id'] as String?,
        status: PurchaseOrderStatus.fromJson(json['status'] as String),
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        items: (json['items'] as List? ?? [])
            .map((e) => PurchaseOrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'purchase_order_number': purchaseOrderNumber,
        'supplier_id': supplierId,
        'order_id': orderId,
        'project_id': projectId,
        'status': status.toJson(),
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
      };
}

/// Legt eine neue Bestellung an — `purchase_order_number` wird serverseitig
/// vergeben. `order_id` ist gesetzt, wenn die Bestellung aus einem
/// Bestellvorschlag (siehe `GET /api/orders/<id>/purchase-proposal`)
/// erzeugt wurde.
class CreatePurchaseOrderRequest {
  const CreatePurchaseOrderRequest({
    this.supplierId,
    this.orderId,
    this.projectId,
    this.notes,
    this.items = const [],
  });

  final String? supplierId;
  final String? orderId;
  final String? projectId;
  final String? notes;
  final List<PurchaseOrderItem> items;

  factory CreatePurchaseOrderRequest.fromJson(Map<String, dynamic> json) => CreatePurchaseOrderRequest(
        supplierId: json['supplier_id'] as String?,
        orderId: json['order_id'] as String?,
        projectId: json['project_id'] as String?,
        notes: json['notes'] as String?,
        items: (json['items'] as List? ?? [])
            .map((e) => PurchaseOrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'supplier_id': supplierId,
        'order_id': orderId,
        'project_id': projectId,
        'notes': notes,
        'items': items.map((item) => item.toJson()).toList(),
      };
}

/// Aktualisiert eine Bestellung — `purchase_order_number` und `order_id`
/// bleiben unverändert.
class UpdatePurchaseOrderRequest {
  const UpdatePurchaseOrderRequest({
    this.supplierId,
    this.projectId,
    this.status = PurchaseOrderStatus.open,
    this.notes,
    this.items = const [],
  });

  final String? supplierId;
  final String? projectId;
  final PurchaseOrderStatus status;
  final String? notes;
  final List<PurchaseOrderItem> items;

  factory UpdatePurchaseOrderRequest.fromJson(Map<String, dynamic> json) => UpdatePurchaseOrderRequest(
        supplierId: json['supplier_id'] as String?,
        projectId: json['project_id'] as String?,
        status: PurchaseOrderStatus.fromJson(json['status'] as String),
        notes: json['notes'] as String?,
        items: (json['items'] as List? ?? [])
            .map((e) => PurchaseOrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'supplier_id': supplierId,
        'project_id': projectId,
        'status': status.toJson(),
        'notes': notes,
        'items': items.map((item) => item.toJson()).toList(),
      };
}

/// Erfasst einen Wareneingang: je Position die neu gelieferte Menge
/// (`delivered`), die zur bisherigen `quantity_delivered` addiert wird.
/// Der Server berechnet daraus den neuen [PurchaseOrderStatus].
class ReceivePurchaseOrderRequest {
  const ReceivePurchaseOrderRequest({required this.items});

  final List<ReceivePurchaseOrderItem> items;

  factory ReceivePurchaseOrderRequest.fromJson(Map<String, dynamic> json) => ReceivePurchaseOrderRequest(
        items: (json['items'] as List? ?? [])
            .map((e) => ReceivePurchaseOrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {'items': items.map((item) => item.toJson()).toList()};
}

class ReceivePurchaseOrderItem {
  const ReceivePurchaseOrderItem({required this.id, required this.delivered});

  /// ID der `purchase_order_items`-Position.
  final String id;

  /// Zusätzlich gelieferte Menge (wird zu `quantity_delivered` addiert).
  final double delivered;

  factory ReceivePurchaseOrderItem.fromJson(Map<String, dynamic> json) => ReceivePurchaseOrderItem(
        id: json['id'] as String,
        delivered: (json['delivered'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'delivered': delivered};
}

/// Vorschlag, wie viel eines Artikels nachbestellt werden sollte —
/// `requiredQuantity` ist der Bedarf aus dem Auftrag (inkl. in Produkten
/// enthaltener Artikel), `stockQuantity` der aktuelle Lagerbestand,
/// `alreadyOrderedQuantity` die Menge, die für diesen Auftrag bereits in
/// einer bestehenden Bestellung steckt (Idempotenz — verhindert
/// Doppelbestellung bei erneutem Abruf/Sync-Retry), `orderQuantity =
/// max(0, requiredQuantity - stockQuantity - alreadyOrderedQuantity)` die
/// vorgeschlagene Restbestellmenge. `sources` zeigt, aus welchen
/// Auftrags-Positionsgruppen sich `requiredQuantity` zusammensetzt.
class PurchaseProposalItem {
  const PurchaseProposalItem({
    required this.articleId,
    required this.description,
    this.unit,
    required this.requiredQuantity,
    required this.stockQuantity,
    this.alreadyOrderedQuantity = 0,
    required this.orderQuantity,
    this.unitPrice,
    this.sources = const [],
  });

  final String articleId;
  final String description;
  final String? unit;
  final double requiredQuantity;
  final double stockQuantity;
  final double alreadyOrderedQuantity;
  final double orderQuantity;
  final double? unitPrice;
  final List<PurchaseOrderItemSource> sources;

  factory PurchaseProposalItem.fromJson(Map<String, dynamic> json) => PurchaseProposalItem(
        articleId: json['article_id'] as String,
        description: json['description'] as String,
        unit: json['unit'] as String?,
        requiredQuantity: (json['required_quantity'] as num).toDouble(),
        stockQuantity: (json['stock_quantity'] as num).toDouble(),
        alreadyOrderedQuantity: (json['already_ordered_quantity'] as num? ?? 0).toDouble(),
        orderQuantity: (json['order_quantity'] as num).toDouble(),
        unitPrice: (json['unit_price'] as num?)?.toDouble(),
        sources: (json['sources'] as List? ?? [])
            .map((e) => PurchaseOrderItemSource.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'article_id': articleId,
        'description': description,
        'unit': unit,
        'required_quantity': requiredQuantity,
        'stock_quantity': stockQuantity,
        'already_ordered_quantity': alreadyOrderedQuantity,
        'order_quantity': orderQuantity,
        'unit_price': unitPrice,
        'sources': sources.map((s) => s.toJson()).toList(),
      };
}

/// Bestellvorschlag für einen Lieferanten (oder `supplierId == null` für
/// Artikel ohne hinterlegten Standard-Lieferanten).
class PurchaseProposalGroup {
  const PurchaseProposalGroup({this.supplierId, this.supplierName, required this.items});

  final String? supplierId;
  final String? supplierName;
  final List<PurchaseProposalItem> items;

  factory PurchaseProposalGroup.fromJson(Map<String, dynamic> json) => PurchaseProposalGroup(
        supplierId: json['supplier_id'] as String?,
        supplierName: json['supplier_name'] as String?,
        items: (json['items'] as List? ?? [])
            .map((e) => PurchaseProposalItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'items': items.map((item) => item.toJson()).toList(),
      };
}
