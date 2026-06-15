/// Zahlungsrhythmus eines Abos.
enum PaymentRhythm {
  monthly,
  yearly;

  String toJson() => name;

  static PaymentRhythm fromJson(String value) => PaymentRhythm.values.firstWhere(
        (rhythm) => rhythm.name == value,
        orElse: () => PaymentRhythm.monthly,
      );
}

/// Status eines saasERP-Abos eines Mandanten.
enum SubscriptionStatus {
  active,
  cancelled;

  String toJson() => name;

  static SubscriptionStatus fromJson(String value) => SubscriptionStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => SubscriptionStatus.active,
      );
}

/// Abo eines Mandanten bei saasERP (M3 — eigenes Geschäftsmodell, nicht zu
/// verwechseln mit `MaintenanceContract`, den Wartungsverträgen zwischen
/// Mandant und Endkunde). 1:n je Mandant — eine Historie aus
/// Neuabschluss/Tier-Wechsel/Kündigung; das aktuelle Abo ist das mit
/// `status: active`.
class Subscription {
  const Subscription({
    required this.id,
    required this.tenantId,
    this.tierId,
    this.paymentRhythm = PaymentRhythm.monthly,
    required this.termMonths,
    required this.startDate,
    required this.endDate,
    this.downPayment = 0,
    this.maxPenalty = 0,
    this.status = SubscriptionStatus.active,
    this.cancelledAt,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String? tierId;
  final PaymentRhythm paymentRhythm;
  final int termMonths;
  final DateTime startDate;
  final DateTime endDate;
  final double downPayment;
  final double maxPenalty;
  final SubscriptionStatus status;
  final DateTime? cancelledAt;
  final String? notes;
  final DateTime createdAt;

  /// Restlaufzeit in vollen Monaten zwischen [from] und [endDate] (>= 0),
  /// geclamped auf die Vertragslaufzeit — Grundlage für die
  /// Vertragsstrafen-Berechnung bei vorzeitiger Kündigung (gleiche Formel
  /// wie bei `MaintenanceContract`).
  int remainingMonths(DateTime from) {
    if (!from.isBefore(endDate)) return 0;
    final months = (endDate.year - from.year) * 12 + (endDate.month - from.month);
    return months.clamp(0, termMonths);
  }

  /// Vertragsstrafe gemäß Formel `Strafe = maximale Strafe ×
  /// Restlaufzeit/Laufzeit`, bezogen auf [cancelledAt]. Liefert 0, wenn das
  /// Abo nicht gekündigt ist oder keine Laufzeit hinterlegt ist.
  double get penalty {
    final cancellationDate = cancelledAt;
    if (cancellationDate == null || termMonths <= 0) return 0;
    return maxPenalty * remainingMonths(cancellationDate) / termMonths;
  }

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        tierId: json['tier_id'] as String?,
        paymentRhythm: PaymentRhythm.fromJson(json['payment_rhythm'] as String),
        termMonths: json['term_months'] as int,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        downPayment: (json['down_payment'] as num).toDouble(),
        maxPenalty: (json['max_penalty'] as num).toDouble(),
        status: SubscriptionStatus.fromJson(json['status'] as String),
        cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at'] as String) : null,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'tier_id': tierId,
        'payment_rhythm': paymentRhythm.toJson(),
        'term_months': termMonths,
        'start_date': _dateOnly(startDate),
        'end_date': _dateOnly(endDate),
        'down_payment': downPayment,
        'max_penalty': maxPenalty,
        'status': status.toJson(),
        'cancelled_at': cancelledAt != null ? _dateOnly(cancelledAt!) : null,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Legt ein neues Abo für einen Mandanten an (Plattform-Admin) — Status
/// startet immer als `active`.
class CreateSubscriptionRequest {
  const CreateSubscriptionRequest({
    this.tierId,
    this.paymentRhythm = PaymentRhythm.monthly,
    required this.termMonths,
    required this.startDate,
    required this.endDate,
    this.downPayment = 0,
    this.maxPenalty = 0,
    this.notes,
  });

  final String? tierId;
  final PaymentRhythm paymentRhythm;
  final int termMonths;
  final DateTime startDate;
  final DateTime endDate;
  final double downPayment;
  final double maxPenalty;
  final String? notes;

  factory CreateSubscriptionRequest.fromJson(Map<String, dynamic> json) => CreateSubscriptionRequest(
        tierId: json['tier_id'] as String?,
        paymentRhythm: PaymentRhythm.fromJson(json['payment_rhythm'] as String? ?? 'monthly'),
        termMonths: json['term_months'] as int,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        downPayment: (json['down_payment'] as num?)?.toDouble() ?? 0,
        maxPenalty: (json['max_penalty'] as num?)?.toDouble() ?? 0,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'tier_id': tierId,
        'payment_rhythm': paymentRhythm.toJson(),
        'term_months': termMonths,
        'start_date': _dateOnly(startDate),
        'end_date': _dateOnly(endDate),
        'down_payment': downPayment,
        'max_penalty': maxPenalty,
        'notes': notes,
      };
}

/// Aktualisiert ein Abo — z. B. Tier-Wechsel, Kündigung (`status: cancelled`
/// + `cancelled_at`).
class UpdateSubscriptionRequest {
  const UpdateSubscriptionRequest({
    this.tierId,
    this.paymentRhythm = PaymentRhythm.monthly,
    required this.termMonths,
    required this.startDate,
    required this.endDate,
    this.downPayment = 0,
    this.maxPenalty = 0,
    this.status = SubscriptionStatus.active,
    this.cancelledAt,
    this.notes,
  });

  final String? tierId;
  final PaymentRhythm paymentRhythm;
  final int termMonths;
  final DateTime startDate;
  final DateTime endDate;
  final double downPayment;
  final double maxPenalty;
  final SubscriptionStatus status;
  final DateTime? cancelledAt;
  final String? notes;

  factory UpdateSubscriptionRequest.fromJson(Map<String, dynamic> json) => UpdateSubscriptionRequest(
        tierId: json['tier_id'] as String?,
        paymentRhythm: PaymentRhythm.fromJson(json['payment_rhythm'] as String? ?? 'monthly'),
        termMonths: json['term_months'] as int,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        downPayment: (json['down_payment'] as num?)?.toDouble() ?? 0,
        maxPenalty: (json['max_penalty'] as num?)?.toDouble() ?? 0,
        status: SubscriptionStatus.fromJson(json['status'] as String? ?? 'active'),
        cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at'] as String) : null,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'tier_id': tierId,
        'payment_rhythm': paymentRhythm.toJson(),
        'term_months': termMonths,
        'start_date': _dateOnly(startDate),
        'end_date': _dateOnly(endDate),
        'down_payment': downPayment,
        'max_penalty': maxPenalty,
        'status': status.toJson(),
        'cancelled_at': cancelledAt != null ? _dateOnly(cancelledAt!) : null,
        'notes': notes,
      };
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
