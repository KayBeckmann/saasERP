class Tenant {
  const Tenant({
    required this.id,
    required this.name,
    required this.createdAt,
    this.brandingColor,
    this.companyAddress,
    this.companyTaxId,
    this.logoUrl,
    this.defaultVatRate = 19.0,
    this.reducedVatRate = 7.0,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  /// Primärfarbe des Mandanten als Hex-Code (`#RRGGBB`), `null` für das
  /// generische Theme. Grundlage für mandantenspezifisches Branding
  /// (späteres Whitelabel-Potenzial, auch für die Kunden-App relevant).
  final String? brandingColor;

  /// Firmenadresse für Briefkopf/Belege (mehrzeiliger Freitext).
  final String? companyAddress;

  /// Steuernummer/USt-IdNr. für Briefkopf/Belege.
  final String? companyTaxId;

  /// URL des Firmenlogos (Briefkopf/Belege, Whitelabel).
  final String? logoUrl;

  /// Standard-Umsatzsteuersatz in Prozent (z. B. 19.0).
  final double defaultVatRate;

  /// Ermäßigter Umsatzsteuersatz in Prozent (z. B. 7.0).
  final double reducedVatRate;

  factory Tenant.fromJson(Map<String, dynamic> json) => Tenant(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        brandingColor: json['branding_color'] as String?,
        companyAddress: json['company_address'] as String?,
        companyTaxId: json['company_tax_id'] as String?,
        logoUrl: json['logo_url'] as String?,
        defaultVatRate: (json['default_vat_rate'] as num?)?.toDouble() ?? 19.0,
        reducedVatRate: (json['reduced_vat_rate'] as num?)?.toDouble() ?? 7.0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
        'branding_color': brandingColor,
        'company_address': companyAddress,
        'company_tax_id': companyTaxId,
        'logo_url': logoUrl,
        'default_vat_rate': defaultVatRate,
        'reduced_vat_rate': reducedVatRate,
      };
}

/// Aktualisiert die Mandanten-Konfiguration (Firmendaten, Logo, Steuersätze).
/// Nur für Owner. Felder, die `null` sind, bleiben unverändert.
class UpdateTenantConfigRequest {
  const UpdateTenantConfigRequest({
    this.companyAddress,
    this.companyTaxId,
    this.logoUrl,
    required this.defaultVatRate,
    required this.reducedVatRate,
  });

  final String? companyAddress;
  final String? companyTaxId;
  final String? logoUrl;
  final double defaultVatRate;
  final double reducedVatRate;

  factory UpdateTenantConfigRequest.fromJson(Map<String, dynamic> json) =>
      UpdateTenantConfigRequest(
        companyAddress: json['company_address'] as String?,
        companyTaxId: json['company_tax_id'] as String?,
        logoUrl: json['logo_url'] as String?,
        defaultVatRate: (json['default_vat_rate'] as num).toDouble(),
        reducedVatRate: (json['reduced_vat_rate'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'company_address': companyAddress,
        'company_tax_id': companyTaxId,
        'logo_url': logoUrl,
        'default_vat_rate': defaultVatRate,
        'reduced_vat_rate': reducedVatRate,
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
