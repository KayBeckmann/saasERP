/// Lieferant eines Mandanten (Freitext-first, analog [[Customer]]).
///
/// `email`, `phone`, `address`, `iban` und `notes` werden serverseitig
/// feldverschlüsselt gespeichert (Envelope-Encryption, [[FieldCipher]]) und
/// hier bereits entschlüsselt geliefert.
class Supplier {
  const Supplier({
    required this.id,
    required this.tenantId,
    required this.name,
    this.contactPerson,
    this.email,
    this.phone,
    this.address,
    this.iban,
    this.paymentTermsDays,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String name;
  final String? contactPerson;
  final String? email;
  final String? phone;
  final String? address;
  final String? iban;

  /// Zahlungsziel in Tagen (z. B. 14 = "zahlbar innerhalb 14 Tagen").
  final int? paymentTermsDays;
  final String? notes;
  final DateTime createdAt;

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        name: json['name'] as String,
        contactPerson: json['contact_person'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        iban: json['iban'] as String?,
        paymentTermsDays: json['payment_terms_days'] as int?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'name': name,
        'contact_person': contactPerson,
        'email': email,
        'phone': phone,
        'address': address,
        'iban': iban,
        'payment_terms_days': paymentTermsDays,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Legt einen neuen Lieferanten an.
class CreateSupplierRequest {
  const CreateSupplierRequest({
    required this.name,
    this.contactPerson,
    this.email,
    this.phone,
    this.address,
    this.iban,
    this.paymentTermsDays,
    this.notes,
  });

  final String name;
  final String? contactPerson;
  final String? email;
  final String? phone;
  final String? address;
  final String? iban;
  final int? paymentTermsDays;
  final String? notes;

  factory CreateSupplierRequest.fromJson(Map<String, dynamic> json) => CreateSupplierRequest(
        name: json['name'] as String,
        contactPerson: json['contact_person'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        iban: json['iban'] as String?,
        paymentTermsDays: json['payment_terms_days'] as int?,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'contact_person': contactPerson,
        'email': email,
        'phone': phone,
        'address': address,
        'iban': iban,
        'payment_terms_days': paymentTermsDays,
        'notes': notes,
      };
}

/// Aktualisiert einen Lieferanten (vollständiger Ersatz der editierbaren Felder).
class UpdateSupplierRequest {
  const UpdateSupplierRequest({
    required this.name,
    this.contactPerson,
    this.email,
    this.phone,
    this.address,
    this.iban,
    this.paymentTermsDays,
    this.notes,
  });

  final String name;
  final String? contactPerson;
  final String? email;
  final String? phone;
  final String? address;
  final String? iban;
  final int? paymentTermsDays;
  final String? notes;

  factory UpdateSupplierRequest.fromJson(Map<String, dynamic> json) => UpdateSupplierRequest(
        name: json['name'] as String,
        contactPerson: json['contact_person'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        iban: json['iban'] as String?,
        paymentTermsDays: json['payment_terms_days'] as int?,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'contact_person': contactPerson,
        'email': email,
        'phone': phone,
        'address': address,
        'iban': iban,
        'payment_terms_days': paymentTermsDays,
        'notes': notes,
      };
}
