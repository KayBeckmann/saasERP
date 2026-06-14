/// Status eines Kundenportal-Zugangs.
enum CustomerPortalAccountStatus {
  /// Einladung versendet, Endkunde hat noch kein Passwort vergeben.
  invited,

  /// Endkunde hat über den Einladungslink ein Passwort vergeben.
  active;

  String toJson() => name;

  static CustomerPortalAccountStatus fromJson(String value) =>
      CustomerPortalAccountStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => CustomerPortalAccountStatus.invited,
      );
}

/// Zugang eines Endkunden zum Kundenportal (`app_kunde`) — verknüpft mit
/// genau einem [Customer]. Wird vom Mandanten in der User-App angelegt
/// (Einladungslink), das Passwort vergibt der Endkunde selbst.
///
/// `inviteToken`/`inviteUrl` sind nur gesetzt, solange [status] `invited`
/// ist — danach kennt nur noch der Endkunde sein Passwort.
class CustomerPortalAccount {
  const CustomerPortalAccount({
    required this.id,
    required this.tenantId,
    required this.customerId,
    required this.email,
    required this.status,
    required this.invitedAt,
    this.activatedAt,
    required this.createdAt,
    this.inviteToken,
    this.inviteUrl,
  });

  final String id;
  final String tenantId;
  final String customerId;
  final String email;
  final CustomerPortalAccountStatus status;
  final DateTime invitedAt;
  final DateTime? activatedAt;
  final DateTime createdAt;
  final String? inviteToken;
  final String? inviteUrl;

  factory CustomerPortalAccount.fromJson(Map<String, dynamic> json) => CustomerPortalAccount(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        customerId: json['customer_id'] as String,
        email: json['email'] as String,
        status: CustomerPortalAccountStatus.fromJson(json['status'] as String),
        invitedAt: DateTime.parse(json['invited_at'] as String),
        activatedAt: json['activated_at'] == null ? null : DateTime.parse(json['activated_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        inviteToken: json['invite_token'] as String?,
        inviteUrl: json['invite_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'customer_id': customerId,
        'email': email,
        'status': status.toJson(),
        'invited_at': invitedAt.toIso8601String(),
        'activated_at': activatedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        if (inviteToken != null) 'invite_token': inviteToken,
        if (inviteUrl != null) 'invite_url': inviteUrl,
      };
}

/// Legt einen Kundenportal-Zugang für einen `Customer` an. `email` ist
/// optional — fehlt sie, übernimmt das Backend `Customer.email`.
class CreateCustomerPortalAccountRequest {
  const CreateCustomerPortalAccountRequest({this.email});

  final String? email;

  factory CreateCustomerPortalAccountRequest.fromJson(Map<String, dynamic> json) =>
      CreateCustomerPortalAccountRequest(email: json['email'] as String?);

  Map<String, dynamic> toJson() => {'email': email};
}

/// Endkunde vergibt über den Einladungslink sein Passwort.
class AcceptCustomerInviteRequest {
  const AcceptCustomerInviteRequest({required this.password});

  final String password;

  factory AcceptCustomerInviteRequest.fromJson(Map<String, dynamic> json) =>
      AcceptCustomerInviteRequest(password: json['password'] as String);

  Map<String, dynamic> toJson() => {'password': password};
}

/// Vorschau-Informationen zu einem Einladungslink (vor Passwortvergabe) —
/// für die Anzeige "Sie wurden von <tenantName> als <customerName> eingeladen".
class CustomerInvitePreview {
  const CustomerInvitePreview({
    required this.tenantName,
    required this.customerName,
    required this.email,
    required this.status,
  });

  final String tenantName;
  final String customerName;
  final String email;
  final CustomerPortalAccountStatus status;

  factory CustomerInvitePreview.fromJson(Map<String, dynamic> json) => CustomerInvitePreview(
        tenantName: json['tenant_name'] as String,
        customerName: json['customer_name'] as String,
        email: json['email'] as String,
        status: CustomerPortalAccountStatus.fromJson(json['status'] as String),
      );

  Map<String, dynamic> toJson() => {
        'tenant_name': tenantName,
        'customer_name': customerName,
        'email': email,
        'status': status.toJson(),
      };
}
