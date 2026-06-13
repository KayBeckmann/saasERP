/// Anfrage für den Artikel-Preisimport: CSV-Text mit Zeilen
/// `sku,einkaufspreis` (Komma oder Semikolon als Trenner, optionale
/// Kopfzeile wird automatisch erkannt, da sie sich nicht als Zahl
/// parsen lässt).
class ArticlePriceImportRequest {
  const ArticlePriceImportRequest({required this.csv});

  final String csv;

  factory ArticlePriceImportRequest.fromJson(Map<String, dynamic> json) =>
      ArticlePriceImportRequest(csv: json['csv'] as String);

  Map<String, dynamic> toJson() => {'csv': csv};
}

/// Aktualisierter Einkaufspreis eines Artikels durch den Preisimport.
class ArticlePriceUpdate {
  const ArticlePriceUpdate({
    required this.articleId,
    required this.sku,
    required this.name,
    this.oldPurchasePrice,
    required this.newPurchasePrice,
  });

  final String articleId;
  final String sku;
  final String name;
  final double? oldPurchasePrice;
  final double newPurchasePrice;

  factory ArticlePriceUpdate.fromJson(Map<String, dynamic> json) => ArticlePriceUpdate(
        articleId: json['article_id'] as String,
        sku: json['sku'] as String,
        name: json['name'] as String,
        oldPurchasePrice: (json['old_purchase_price'] as num?)?.toDouble(),
        newPurchasePrice: (json['new_purchase_price'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'article_id': articleId,
        'sku': sku,
        'name': name,
        'old_purchase_price': oldPurchasePrice,
        'new_purchase_price': newPurchasePrice,
      };
}

/// Neuer Verkaufspreis-Vorschlag für ein Produkt, das einen der
/// importierten Artikel als Position enthält.
class ProductPriceSuggestion {
  const ProductPriceSuggestion({
    required this.productId,
    required this.name,
    required this.oldSalePrice,
    required this.pendingSalePrice,
  });

  final String productId;
  final String name;
  final double oldSalePrice;
  final double pendingSalePrice;

  factory ProductPriceSuggestion.fromJson(Map<String, dynamic> json) => ProductPriceSuggestion(
        productId: json['product_id'] as String,
        name: json['name'] as String,
        oldSalePrice: (json['old_sale_price'] as num).toDouble(),
        pendingSalePrice: (json['pending_sale_price'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'name': name,
        'old_sale_price': oldSalePrice,
        'pending_sale_price': pendingSalePrice,
      };
}

/// Ergebnis eines Artikel-Preisimports.
class ArticlePriceImportResult {
  const ArticlePriceImportResult({
    required this.updatedArticles,
    required this.notFoundSkus,
    required this.productSuggestions,
  });

  final List<ArticlePriceUpdate> updatedArticles;
  final List<String> notFoundSkus;
  final List<ProductPriceSuggestion> productSuggestions;

  factory ArticlePriceImportResult.fromJson(Map<String, dynamic> json) => ArticlePriceImportResult(
        updatedArticles: (json['updated_articles'] as List)
            .map((e) => ArticlePriceUpdate.fromJson(e as Map<String, dynamic>))
            .toList(),
        notFoundSkus: (json['not_found_skus'] as List).cast<String>(),
        productSuggestions: (json['product_suggestions'] as List)
            .map((e) => ProductPriceSuggestion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'updated_articles': updatedArticles.map((u) => u.toJson()).toList(),
        'not_found_skus': notFoundSkus,
        'product_suggestions': productSuggestions.map((s) => s.toJson()).toList(),
      };
}
