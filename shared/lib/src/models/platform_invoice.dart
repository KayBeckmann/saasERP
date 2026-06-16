import 'subscription.dart';

/// Status einer Plattform-Rechnung (saasERP → Mandant, M4).
enum PlatformInvoiceStatus {
  open,
  paid,
  overdue,
  cancelled;

  String toJson() => name;

  static PlatformInvoiceStatus fromJson(String value) => PlatformInvoiceStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => PlatformInvoiceStatus.open,
      );
}

/// Plattform-Rechnung: saasERP rechnet sein eigenes Produkt bei einem
/// Mandanten ab ("Eat your own dog food", M4 — Zahlungsabwicklung). Eine
/// Rechnung je Abrechnungsperiode, optional verknüpft mit dem Abo, aus dem
/// sich der Betrag ergibt.
class PlatformInvoice {
  const PlatformInvoice({
    required this.id,
    required this.tenantId,
    this.subscriptionId,
    required this.invoiceNumber,
    required this.periodStart,
    required this.periodEnd,
    this.amount = 0,
    this.paymentMethod = PaymentMethod.bankTransfer,
    this.status = PlatformInvoiceStatus.open,
    required this.dueDate,
    this.paidAt,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String? subscriptionId;
  final String invoiceNumber;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double amount;
  final PaymentMethod paymentMethod;
  final PlatformInvoiceStatus status;
  final DateTime dueDate;
  final DateTime? paidAt;
  final String? notes;
  final DateTime createdAt;

  factory PlatformInvoice.fromJson(Map<String, dynamic> json) => PlatformInvoice(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        subscriptionId: json['subscription_id'] as String?,
        invoiceNumber: json['invoice_number'] as String,
        periodStart: DateTime.parse(json['period_start'] as String),
        periodEnd: DateTime.parse(json['period_end'] as String),
        amount: (json['amount'] as num).toDouble(),
        paymentMethod: PaymentMethod.fromJson(json['payment_method'] as String? ?? 'bank_transfer'),
        status: PlatformInvoiceStatus.fromJson(json['status'] as String),
        dueDate: DateTime.parse(json['due_date'] as String),
        paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : null,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'subscription_id': subscriptionId,
        'invoice_number': invoiceNumber,
        'period_start': _dateOnly(periodStart),
        'period_end': _dateOnly(periodEnd),
        'amount': amount,
        'payment_method': paymentMethod.toJson(),
        'status': status.toJson(),
        'due_date': _dateOnly(dueDate),
        'paid_at': paidAt != null ? _dateOnly(paidAt!) : null,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Legt eine neue Plattform-Rechnung für einen Mandanten an
/// (Plattform-Admin) — Status startet immer als `open`.
class CreatePlatformInvoiceRequest {
  const CreatePlatformInvoiceRequest({
    this.subscriptionId,
    required this.periodStart,
    required this.periodEnd,
    this.amount = 0,
    this.paymentMethod = PaymentMethod.bankTransfer,
    required this.dueDate,
    this.notes,
  });

  final String? subscriptionId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double amount;
  final PaymentMethod paymentMethod;
  final DateTime dueDate;
  final String? notes;

  factory CreatePlatformInvoiceRequest.fromJson(Map<String, dynamic> json) => CreatePlatformInvoiceRequest(
        subscriptionId: json['subscription_id'] as String?,
        periodStart: DateTime.parse(json['period_start'] as String),
        periodEnd: DateTime.parse(json['period_end'] as String),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        paymentMethod: PaymentMethod.fromJson(json['payment_method'] as String? ?? 'bank_transfer'),
        dueDate: DateTime.parse(json['due_date'] as String),
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'subscription_id': subscriptionId,
        'period_start': _dateOnly(periodStart),
        'period_end': _dateOnly(periodEnd),
        'amount': amount,
        'payment_method': paymentMethod.toJson(),
        'due_date': _dateOnly(dueDate),
        'notes': notes,
      };
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
