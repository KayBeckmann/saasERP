/// Artikel eines Mandanten (Freitext-first: nur `name` ist Pflicht).
///
/// `usageCount` wird serverseitig hochgezählt, sobald ein Artikel in einem
/// Beleg (Angebot/Auftrag/Rechnung) verwendet wird, und dient später als
/// Sortierkriterium für "häufig verwendet" in Positions-Pickern.
class Article {
  const Article({
    required this.id,
    required this.tenantId,
    this.sku,
    this.supplierSku,
    required this.name,
    this.unit,
    this.purchasePrice,
    this.salePrice,
    this.vatRate = 19.0,
    this.usageCount = 0,
    this.stockQuantity = 0,
    this.minimumStock = 0,
    this.defaultSupplierId,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String tenantId;

  /// Eigene interne Artikelnummer / SKU — frei vergeben, kein Nummernkreis.
  final String? sku;

  /// Artikelnummer des Lieferanten — wird auf Bestellungen abgedruckt.
  final String? supplierSku;

  final String name;

  /// Einheit als Freitext (z. B. "Stück", "kg", "m").
  final String? unit;

  final double? purchasePrice;
  final double? salePrice;
  final double vatRate;

  /// Zähler, wie oft der Artikel bereits in Belegen verwendet wurde.
  final int usageCount;

  /// Aktueller Lagerbestand — Basis für den Bestellvorschlag
  /// (Fehlmenge = Bedarf − Bestand) und die spätere Lagerverwaltung.
  final double stockQuantity;

  /// Mindestbestand — Basis für den Hinweis in der Bestandsübersicht,
  /// wenn `stockQuantity` darunter fällt.
  final double minimumStock;

  /// Bevorzugter Lieferant für diesen Artikel — Basis für die Gruppierung
  /// des Bestellvorschlags je Lieferant.
  final String? defaultSupplierId;
  final String? notes;
  final DateTime createdAt;

  factory Article.fromJson(Map<String, dynamic> json) => Article(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        sku: json['sku'] as String?,
        supplierSku: json['supplier_sku'] as String?,
        name: json['name'] as String,
        unit: json['unit'] as String?,
        purchasePrice: (json['purchase_price'] as num?)?.toDouble(),
        salePrice: (json['sale_price'] as num?)?.toDouble(),
        vatRate: (json['vat_rate'] as num).toDouble(),
        usageCount: json['usage_count'] as int,
        stockQuantity: (json['stock_quantity'] as num? ?? 0).toDouble(),
        minimumStock: (json['minimum_stock'] as num? ?? 0).toDouble(),
        defaultSupplierId: json['default_supplier_id'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'sku': sku,
        'supplier_sku': supplierSku,
        'name': name,
        'unit': unit,
        'purchase_price': purchasePrice,
        'sale_price': salePrice,
        'vat_rate': vatRate,
        'usage_count': usageCount,
        'stock_quantity': stockQuantity,
        'minimum_stock': minimumStock,
        'default_supplier_id': defaultSupplierId,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Legt einen neuen Artikel an.
class CreateArticleRequest {
  const CreateArticleRequest({
    this.sku,
    this.supplierSku,
    required this.name,
    this.unit,
    this.purchasePrice,
    this.salePrice,
    this.vatRate = 19.0,
    this.stockQuantity = 0,
    this.minimumStock = 0,
    this.defaultSupplierId,
    this.notes,
  });

  final String? sku;
  final String? supplierSku;
  final String name;
  final String? unit;
  final double? purchasePrice;
  final double? salePrice;
  final double vatRate;
  final double stockQuantity;
  final double minimumStock;
  final String? defaultSupplierId;
  final String? notes;

  factory CreateArticleRequest.fromJson(Map<String, dynamic> json) => CreateArticleRequest(
        sku: json['sku'] as String?,
        supplierSku: json['supplier_sku'] as String?,
        name: json['name'] as String,
        unit: json['unit'] as String?,
        purchasePrice: (json['purchase_price'] as num?)?.toDouble(),
        salePrice: (json['sale_price'] as num?)?.toDouble(),
        vatRate: json['vat_rate'] == null ? 19.0 : (json['vat_rate'] as num).toDouble(),
        stockQuantity: (json['stock_quantity'] as num? ?? 0).toDouble(),
        minimumStock: (json['minimum_stock'] as num? ?? 0).toDouble(),
        defaultSupplierId: json['default_supplier_id'] as String?,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'sku': sku,
        'supplier_sku': supplierSku,
        'name': name,
        'unit': unit,
        'purchase_price': purchasePrice,
        'sale_price': salePrice,
        'vat_rate': vatRate,
        'stock_quantity': stockQuantity,
        'minimum_stock': minimumStock,
        'default_supplier_id': defaultSupplierId,
        'notes': notes,
      };
}

/// Aktualisiert einen Artikel (vollständiger Ersatz der editierbaren Felder,
/// `usage_count` bleibt unverändert).
class UpdateArticleRequest {
  const UpdateArticleRequest({
    this.sku,
    this.supplierSku,
    required this.name,
    this.unit,
    this.purchasePrice,
    this.salePrice,
    this.vatRate = 19.0,
    this.stockQuantity = 0,
    this.minimumStock = 0,
    this.defaultSupplierId,
    this.notes,
  });

  final String? sku;
  final String? supplierSku;
  final String name;
  final String? unit;
  final double? purchasePrice;
  final double? salePrice;
  final double vatRate;
  final double stockQuantity;
  final double minimumStock;
  final String? defaultSupplierId;
  final String? notes;

  factory UpdateArticleRequest.fromJson(Map<String, dynamic> json) => UpdateArticleRequest(
        sku: json['sku'] as String?,
        supplierSku: json['supplier_sku'] as String?,
        name: json['name'] as String,
        unit: json['unit'] as String?,
        purchasePrice: (json['purchase_price'] as num?)?.toDouble(),
        salePrice: (json['sale_price'] as num?)?.toDouble(),
        vatRate: json['vat_rate'] == null ? 19.0 : (json['vat_rate'] as num).toDouble(),
        stockQuantity: (json['stock_quantity'] as num? ?? 0).toDouble(),
        minimumStock: (json['minimum_stock'] as num? ?? 0).toDouble(),
        defaultSupplierId: json['default_supplier_id'] as String?,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'sku': sku,
        'supplier_sku': supplierSku,
        'name': name,
        'unit': unit,
        'purchase_price': purchasePrice,
        'sale_price': salePrice,
        'vat_rate': vatRate,
        'stock_quantity': stockQuantity,
        'minimum_stock': minimumStock,
        'default_supplier_id': defaultSupplierId,
        'notes': notes,
      };
}
