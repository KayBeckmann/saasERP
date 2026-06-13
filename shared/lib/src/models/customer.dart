/// Art des Kunden — beeinflusst Anzeige (Firma vs. Person) und
/// E-Rechnungs-Anforderungen (B2G/Behörden benötigen eine Leitweg-ID).
enum CustomerKind {
  private,
  business,
  authority;

  String toJson() => name;

  static CustomerKind fromJson(String value) => CustomerKind.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () => CustomerKind.private,
      );
}

/// E-Rechnungsformat für Ausgangsrechnungen an diesen Kunden.
enum EInvoiceFormat {
  none,
  xrechnung,
  zugferd;

  String toJson() => name;

  static EInvoiceFormat fromJson(String value) => EInvoiceFormat.values.firstWhere(
        (format) => format.name == value,
        orElse: () => EInvoiceFormat.none,
      );
}

/// Kunde eines Mandanten (Freitext-first: Name/Adresse als formlose Felder,
/// strukturierte Stammdaten wachsen organisch bei Bedarf).
///
/// `email`, `phone`, `address` und `notes` werden serverseitig
/// feldverschlüsselt gespeichert (Envelope-Encryption, [[FieldCipher]]) und
/// hier bereits entschlüsselt geliefert.
class Customer {
  const Customer({
    required this.id,
    required this.tenantId,
    required this.customerNumber,
    required this.kind,
    required this.name,
    this.contactPerson,
    this.email,
    this.phone,
    this.address,
    this.eInvoiceFormat = EInvoiceFormat.none,
    this.leitwegId,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String tenantId;

  /// Automatisch vergebene Kundennummer (Nummernkreis, z. B. "K0001").
  final String customerNumber;

  final CustomerKind kind;
  final String name;
  final String? contactPerson;
  final String? email;
  final String? phone;
  final String? address;
  final EInvoiceFormat eInvoiceFormat;

  /// Leitweg-ID für XRechnung an öffentliche Auftraggeber (B2G).
  final String? leitwegId;
  final String? notes;
  final DateTime createdAt;

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        customerNumber: json['customer_number'] as String,
        kind: CustomerKind.fromJson(json['kind'] as String),
        name: json['name'] as String,
        contactPerson: json['contact_person'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        eInvoiceFormat: EInvoiceFormat.fromJson(json['e_invoice_format'] as String),
        leitwegId: json['leitweg_id'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'customer_number': customerNumber,
        'kind': kind.toJson(),
        'name': name,
        'contact_person': contactPerson,
        'email': email,
        'phone': phone,
        'address': address,
        'e_invoice_format': eInvoiceFormat.toJson(),
        'leitweg_id': leitwegId,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Legt einen neuen Kunden an — `customer_number` wird serverseitig über
/// den Nummernkreis vergeben.
class CreateCustomerRequest {
  const CreateCustomerRequest({
    required this.kind,
    required this.name,
    this.contactPerson,
    this.email,
    this.phone,
    this.address,
    this.eInvoiceFormat = EInvoiceFormat.none,
    this.leitwegId,
    this.notes,
  });

  final CustomerKind kind;
  final String name;
  final String? contactPerson;
  final String? email;
  final String? phone;
  final String? address;
  final EInvoiceFormat eInvoiceFormat;
  final String? leitwegId;
  final String? notes;

  factory CreateCustomerRequest.fromJson(Map<String, dynamic> json) => CreateCustomerRequest(
        kind: CustomerKind.fromJson(json['kind'] as String),
        name: json['name'] as String,
        contactPerson: json['contact_person'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        eInvoiceFormat: json['e_invoice_format'] == null
            ? EInvoiceFormat.none
            : EInvoiceFormat.fromJson(json['e_invoice_format'] as String),
        leitwegId: json['leitweg_id'] as String?,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.toJson(),
        'name': name,
        'contact_person': contactPerson,
        'email': email,
        'phone': phone,
        'address': address,
        'e_invoice_format': eInvoiceFormat.toJson(),
        'leitweg_id': leitwegId,
        'notes': notes,
      };
}

/// Aktualisiert einen Kunden (vollständiger Ersatz der editierbaren Felder,
/// `customer_number` bleibt unverändert).
class UpdateCustomerRequest {
  const UpdateCustomerRequest({
    required this.kind,
    required this.name,
    this.contactPerson,
    this.email,
    this.phone,
    this.address,
    this.eInvoiceFormat = EInvoiceFormat.none,
    this.leitwegId,
    this.notes,
  });

  final CustomerKind kind;
  final String name;
  final String? contactPerson;
  final String? email;
  final String? phone;
  final String? address;
  final EInvoiceFormat eInvoiceFormat;
  final String? leitwegId;
  final String? notes;

  factory UpdateCustomerRequest.fromJson(Map<String, dynamic> json) => UpdateCustomerRequest(
        kind: CustomerKind.fromJson(json['kind'] as String),
        name: json['name'] as String,
        contactPerson: json['contact_person'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        eInvoiceFormat: json['e_invoice_format'] == null
            ? EInvoiceFormat.none
            : EInvoiceFormat.fromJson(json['e_invoice_format'] as String),
        leitwegId: json['leitweg_id'] as String?,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.toJson(),
        'name': name,
        'contact_person': contactPerson,
        'email': email,
        'phone': phone,
        'address': address,
        'e_invoice_format': eInvoiceFormat.toJson(),
        'leitweg_id': leitwegId,
        'notes': notes,
      };
}
