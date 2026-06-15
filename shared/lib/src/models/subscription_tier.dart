/// Abo-Tier von saasERP (z. B. "Starter"/"Professional"/"Enterprise") —
/// global vom Plattform-Admin gepflegt, nicht mandanten-gescopt.
class SubscriptionTier {
  const SubscriptionTier({
    required this.id,
    required this.name,
    this.monthlyPrice = 0,
    this.yearlyPrice = 0,
    this.userLimit,
    this.featureSummary,
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
  });

  final String id;
  final String name;
  final double monthlyPrice;
  final double yearlyPrice;

  /// `null` = unbegrenzte Benutzerzahl.
  final int? userLimit;
  final String? featureSummary;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;

  factory SubscriptionTier.fromJson(Map<String, dynamic> json) => SubscriptionTier(
        id: json['id'] as String,
        name: json['name'] as String,
        monthlyPrice: (json['monthly_price'] as num).toDouble(),
        yearlyPrice: (json['yearly_price'] as num).toDouble(),
        userLimit: json['user_limit'] as int?,
        featureSummary: json['feature_summary'] as String?,
        sortOrder: json['sort_order'] as int,
        isActive: json['is_active'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'monthly_price': monthlyPrice,
        'yearly_price': yearlyPrice,
        'user_limit': userLimit,
        'feature_summary': featureSummary,
        'sort_order': sortOrder,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Legt ein neues Abo-Tier an (Plattform-Admin).
class CreateSubscriptionTierRequest {
  const CreateSubscriptionTierRequest({
    required this.name,
    this.monthlyPrice = 0,
    this.yearlyPrice = 0,
    this.userLimit,
    this.featureSummary,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String name;
  final double monthlyPrice;
  final double yearlyPrice;
  final int? userLimit;
  final String? featureSummary;
  final int sortOrder;
  final bool isActive;

  factory CreateSubscriptionTierRequest.fromJson(Map<String, dynamic> json) => CreateSubscriptionTierRequest(
        name: json['name'] as String,
        monthlyPrice: (json['monthly_price'] as num?)?.toDouble() ?? 0,
        yearlyPrice: (json['yearly_price'] as num?)?.toDouble() ?? 0,
        userLimit: json['user_limit'] as int?,
        featureSummary: json['feature_summary'] as String?,
        sortOrder: json['sort_order'] as int? ?? 0,
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'monthly_price': monthlyPrice,
        'yearly_price': yearlyPrice,
        'user_limit': userLimit,
        'feature_summary': featureSummary,
        'sort_order': sortOrder,
        'is_active': isActive,
      };
}

/// Aktualisiert ein Abo-Tier (Plattform-Admin).
class UpdateSubscriptionTierRequest {
  const UpdateSubscriptionTierRequest({
    required this.name,
    this.monthlyPrice = 0,
    this.yearlyPrice = 0,
    this.userLimit,
    this.featureSummary,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String name;
  final double monthlyPrice;
  final double yearlyPrice;
  final int? userLimit;
  final String? featureSummary;
  final int sortOrder;
  final bool isActive;

  factory UpdateSubscriptionTierRequest.fromJson(Map<String, dynamic> json) => UpdateSubscriptionTierRequest(
        name: json['name'] as String,
        monthlyPrice: (json['monthly_price'] as num?)?.toDouble() ?? 0,
        yearlyPrice: (json['yearly_price'] as num?)?.toDouble() ?? 0,
        userLimit: json['user_limit'] as int?,
        featureSummary: json['feature_summary'] as String?,
        sortOrder: json['sort_order'] as int? ?? 0,
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'monthly_price': monthlyPrice,
        'yearly_price': yearlyPrice,
        'user_limit': userLimit,
        'feature_summary': featureSummary,
        'sort_order': sortOrder,
        'is_active': isActive,
      };
}
