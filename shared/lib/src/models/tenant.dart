class Tenant {
  const Tenant({
    required this.id,
    required this.name,
    required this.createdAt,
    this.brandingColor,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  /// Primärfarbe des Mandanten als Hex-Code (`#RRGGBB`), `null` für das
  /// generische Theme. Grundlage für mandantenspezifisches Branding
  /// (späteres Whitelabel-Potenzial, auch für die Kunden-App relevant).
  final String? brandingColor;

  factory Tenant.fromJson(Map<String, dynamic> json) => Tenant(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        brandingColor: json['branding_color'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
        'branding_color': brandingColor,
      };
}

/// Aktualisiert das Branding des aktuellen Mandanten (nur Owner).
/// `brandingColor: null` setzt den Mandanten auf das generische Theme zurück.
class UpdateTenantBrandingRequest {
  const UpdateTenantBrandingRequest({this.brandingColor});

  final String? brandingColor;

  factory UpdateTenantBrandingRequest.fromJson(Map<String, dynamic> json) =>
      UpdateTenantBrandingRequest(
        brandingColor: json['branding_color'] as String?,
      );

  Map<String, dynamic> toJson() => {'branding_color': brandingColor};
}
