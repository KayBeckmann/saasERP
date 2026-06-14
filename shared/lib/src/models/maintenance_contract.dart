/// Status eines Wartungsvertrags/Abos zwischen Mandant und Endkunde.
enum MaintenanceContractStatus {
  active,
  cancelled;

  String toJson() => name;

  static MaintenanceContractStatus fromJson(String value) => MaintenanceContractStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => MaintenanceContractStatus.active,
      );
}

/// Wartungsvertrag/Abo eines Mandanten mit einem Endkunden (z. B. ein
/// Wartungsvertrag eines Handwerksbetriebs mit seinem Kunden) — eigenständige
/// Entität auf Ebene Mandant ↔ Endkunde, nicht zu verwechseln mit saasERPs
/// eigenen Abos (M3). `contractNumber` wird über den Nummernkreis
/// "maintenance_contract" (Prefix "W") vergeben.
class MaintenanceContract {
  const MaintenanceContract({
    required this.id,
    required this.tenantId,
    required this.customerId,
    required this.contractNumber,
    required this.title,
    required this.termMonths,
    required this.startDate,
    required this.endDate,
    this.noticePeriodMonths = 1,
    this.maxPenalty = 0,
    this.status = MaintenanceContractStatus.active,
    this.cancelledAt,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String customerId;
  final String contractNumber;
  final String title;
  final int termMonths;
  final DateTime startDate;
  final DateTime endDate;
  final int noticePeriodMonths;
  final double maxPenalty;
  final MaintenanceContractStatus status;
  final DateTime? cancelledAt;
  final String? notes;
  final DateTime createdAt;

  /// Restlaufzeit in vollen Monaten zwischen [from] und [endDate] (>= 0).
  /// Grundlage für die Vertragsstrafen-Berechnung bei vorzeitiger Kündigung.
  int remainingMonths(DateTime from) {
    if (!from.isBefore(endDate)) return 0;
    final months = (endDate.year - from.year) * 12 + (endDate.month - from.month);
    return months.clamp(0, termMonths);
  }

  /// Vertragsstrafe gemäß M0-Formel `Strafe = maximale Strafe ×
  /// Restlaufzeit/Laufzeit`, bezogen auf [cancelledAt]. Liefert 0, wenn der
  /// Vertrag nicht gekündigt ist oder keine Laufzeit hinterlegt ist.
  double get penalty {
    final cancellationDate = cancelledAt;
    if (cancellationDate == null || termMonths <= 0) return 0;
    return maxPenalty * remainingMonths(cancellationDate) / termMonths;
  }

  factory MaintenanceContract.fromJson(Map<String, dynamic> json) => MaintenanceContract(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        customerId: json['customer_id'] as String,
        contractNumber: json['contract_number'] as String,
        title: json['title'] as String,
        termMonths: json['term_months'] as int,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        noticePeriodMonths: json['notice_period_months'] as int,
        maxPenalty: (json['max_penalty'] as num).toDouble(),
        status: MaintenanceContractStatus.fromJson(json['status'] as String),
        cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at'] as String) : null,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'customer_id': customerId,
        'contract_number': contractNumber,
        'title': title,
        'term_months': termMonths,
        'start_date': _dateOnly(startDate),
        'end_date': _dateOnly(endDate),
        'notice_period_months': noticePeriodMonths,
        'max_penalty': maxPenalty,
        'status': status.toJson(),
        'cancelled_at': cancelledAt != null ? _dateOnly(cancelledAt!) : null,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Legt einen neuen Wartungsvertrag an — `contract_number` wird serverseitig
/// vergeben, Status startet immer als `active`.
class CreateMaintenanceContractRequest {
  const CreateMaintenanceContractRequest({
    required this.customerId,
    required this.title,
    required this.termMonths,
    required this.startDate,
    required this.endDate,
    this.noticePeriodMonths = 1,
    this.maxPenalty = 0,
    this.notes,
  });

  final String customerId;
  final String title;
  final int termMonths;
  final DateTime startDate;
  final DateTime endDate;
  final int noticePeriodMonths;
  final double maxPenalty;
  final String? notes;

  factory CreateMaintenanceContractRequest.fromJson(Map<String, dynamic> json) =>
      CreateMaintenanceContractRequest(
        customerId: json['customer_id'] as String,
        title: json['title'] as String,
        termMonths: json['term_months'] as int,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        noticePeriodMonths: json['notice_period_months'] as int? ?? 1,
        maxPenalty: (json['max_penalty'] as num?)?.toDouble() ?? 0,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'title': title,
        'term_months': termMonths,
        'start_date': _dateOnly(startDate),
        'end_date': _dateOnly(endDate),
        'notice_period_months': noticePeriodMonths,
        'max_penalty': maxPenalty,
        'notes': notes,
      };
}

/// Aktualisiert einen Wartungsvertrag — `contract_number` bleibt unverändert.
/// `cancelledAt` wird gesetzt, wenn der Mandant den Vertrag auf `cancelled`
/// setzt (Basis für die spätere Vertragsstrafen-Berechnung im Kundenportal).
class UpdateMaintenanceContractRequest {
  const UpdateMaintenanceContractRequest({
    required this.customerId,
    required this.title,
    required this.termMonths,
    required this.startDate,
    required this.endDate,
    this.noticePeriodMonths = 1,
    this.maxPenalty = 0,
    this.status = MaintenanceContractStatus.active,
    this.cancelledAt,
    this.notes,
  });

  final String customerId;
  final String title;
  final int termMonths;
  final DateTime startDate;
  final DateTime endDate;
  final int noticePeriodMonths;
  final double maxPenalty;
  final MaintenanceContractStatus status;
  final DateTime? cancelledAt;
  final String? notes;

  factory UpdateMaintenanceContractRequest.fromJson(Map<String, dynamic> json) =>
      UpdateMaintenanceContractRequest(
        customerId: json['customer_id'] as String,
        title: json['title'] as String,
        termMonths: json['term_months'] as int,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        noticePeriodMonths: json['notice_period_months'] as int? ?? 1,
        maxPenalty: (json['max_penalty'] as num?)?.toDouble() ?? 0,
        status: MaintenanceContractStatus.fromJson(json['status'] as String),
        cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at'] as String) : null,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'title': title,
        'term_months': termMonths,
        'start_date': _dateOnly(startDate),
        'end_date': _dateOnly(endDate),
        'notice_period_months': noticePeriodMonths,
        'max_penalty': maxPenalty,
        'status': status.toJson(),
        'cancelled_at': cancelledAt != null ? _dateOnly(cancelledAt!) : null,
        'notes': notes,
      };
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
