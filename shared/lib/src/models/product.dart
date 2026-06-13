/// Art einer Produkt-Position: ein Artikel aus dem Artikelstamm oder eine
/// frei beschriftete Arbeitszeit-Position.
enum ProductComponentKind {
  article,
  labor;

  String toJson() => name;

  static ProductComponentKind fromJson(String value) => ProductComponentKind.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () => ProductComponentKind.article,
      );
}

/// Position innerhalb eines Produkts.
///
/// Bei [ProductComponentKind.article] verweist [articleId] auf einen
/// Artikel, [quantity] ist die Menge und [unitCost] ein Schnappschuss des
/// Einkaufspreises zum Zeitpunkt des Anlegens/letzten Bestätigens.
///
/// Bei [ProductComponentKind.labor] ist [label] die Bezeichnung (z. B.
/// "Montage"), [quantity] die Stundenzahl und [unitCost] der Stundensatz.
class ProductComponent {
  const ProductComponent({
    this.id,
    required this.kind,
    this.articleId,
    this.label,
    required this.quantity,
    required this.unitCost,
  });

  final String? id;
  final ProductComponentKind kind;
  final String? articleId;
  final String? label;
  final double quantity;
  final double unitCost;

  double get totalCost => quantity * unitCost;

  factory ProductComponent.fromJson(Map<String, dynamic> json) => ProductComponent(
        id: json['id'] as String?,
        kind: ProductComponentKind.fromJson(json['kind'] as String),
        articleId: json['article_id'] as String?,
        label: json['label'] as String?,
        quantity: (json['quantity'] as num).toDouble(),
        unitCost: (json['unit_cost'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.toJson(),
        'article_id': articleId,
        'label': label,
        'quantity': quantity,
        'unit_cost': unitCost,
      };
}

/// Produkt eines Mandanten — Bundle aus Artikeln und/oder Arbeitszeit mit
/// eigenem Verkaufspreis (Freitext-first: nur `name` ist Pflicht).
///
/// [pendingSalePrice] ist gesetzt, wenn ein Preisimport zu einer
/// Kostenänderung geführt hat und ein neuer Verkaufspreis als Vorschlag
/// zur Bestätigung bereitsteht.
class Product {
  const Product({
    required this.id,
    required this.tenantId,
    this.sku,
    required this.name,
    required this.salePrice,
    this.pendingSalePrice,
    this.vatRate = 19.0,
    this.notes,
    required this.createdAt,
    this.components = const [],
  });

  final String id;
  final String tenantId;
  final String? sku;
  final String name;
  final double salePrice;
  final double? pendingSalePrice;
  final double vatRate;
  final String? notes;
  final DateTime createdAt;
  final List<ProductComponent> components;

  double get totalCost => components.fold(0, (sum, c) => sum + c.totalCost);

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        sku: json['sku'] as String?,
        name: json['name'] as String,
        salePrice: (json['sale_price'] as num).toDouble(),
        pendingSalePrice: (json['pending_sale_price'] as num?)?.toDouble(),
        vatRate: (json['vat_rate'] as num).toDouble(),
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        components: (json['components'] as List? ?? [])
            .map((e) => ProductComponent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'sku': sku,
        'name': name,
        'sale_price': salePrice,
        'pending_sale_price': pendingSalePrice,
        'vat_rate': vatRate,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'components': components.map((c) => c.toJson()).toList(),
      };
}

/// Legt ein neues Produkt an (inkl. Positionen).
class CreateProductRequest {
  const CreateProductRequest({
    this.sku,
    required this.name,
    required this.salePrice,
    this.vatRate = 19.0,
    this.notes,
    this.components = const [],
  });

  final String? sku;
  final String name;
  final double salePrice;
  final double vatRate;
  final String? notes;
  final List<ProductComponent> components;

  factory CreateProductRequest.fromJson(Map<String, dynamic> json) => CreateProductRequest(
        sku: json['sku'] as String?,
        name: json['name'] as String,
        salePrice: (json['sale_price'] as num).toDouble(),
        vatRate: json['vat_rate'] == null ? 19.0 : (json['vat_rate'] as num).toDouble(),
        notes: json['notes'] as String?,
        components: (json['components'] as List? ?? [])
            .map((e) => ProductComponent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'sku': sku,
        'name': name,
        'sale_price': salePrice,
        'vat_rate': vatRate,
        'notes': notes,
        'components': components.map((c) => c.toJson()).toList(),
      };
}

/// Aktualisiert ein Produkt (vollständiger Ersatz der editierbaren Felder
/// inkl. Positionen, `pending_sale_price` bleibt unverändert).
class UpdateProductRequest {
  const UpdateProductRequest({
    this.sku,
    required this.name,
    required this.salePrice,
    this.vatRate = 19.0,
    this.notes,
    this.components = const [],
  });

  final String? sku;
  final String name;
  final double salePrice;
  final double vatRate;
  final String? notes;
  final List<ProductComponent> components;

  factory UpdateProductRequest.fromJson(Map<String, dynamic> json) => UpdateProductRequest(
        sku: json['sku'] as String?,
        name: json['name'] as String,
        salePrice: (json['sale_price'] as num).toDouble(),
        vatRate: json['vat_rate'] == null ? 19.0 : (json['vat_rate'] as num).toDouble(),
        notes: json['notes'] as String?,
        components: (json['components'] as List? ?? [])
            .map((e) => ProductComponent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'sku': sku,
        'name': name,
        'sale_price': salePrice,
        'vat_rate': vatRate,
        'notes': notes,
        'components': components.map((c) => c.toJson()).toList(),
      };
}
