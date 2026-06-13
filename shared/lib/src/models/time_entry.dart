/// Ein Stundenerfassungs-Eintrag eines Nutzers für einen Arbeitstag,
/// optional einem Auftrag zugeordnet (für spätere Abrechnung).
class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.tenantId,
    required this.userId,
    this.orderId,
    required this.workDate,
    required this.hours,
    this.description,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String userId;
  final String? orderId;

  /// Arbeitstag (ohne Zeitanteil).
  final DateTime workDate;
  final double hours;
  final String? description;
  final DateTime createdAt;

  factory TimeEntry.fromJson(Map<String, dynamic> json) => TimeEntry(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        userId: json['user_id'] as String,
        orderId: json['order_id'] as String?,
        workDate: DateTime.parse(json['work_date'] as String),
        hours: (json['hours'] as num).toDouble(),
        description: json['description'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'user_id': userId,
        'order_id': orderId,
        'work_date': _dateOnly(workDate),
        'hours': hours,
        'description': description,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Legt einen neuen Stundenerfassungs-Eintrag an.
class CreateTimeEntryRequest {
  const CreateTimeEntryRequest({
    this.orderId,
    required this.workDate,
    required this.hours,
    this.description,
  });

  final String? orderId;
  final DateTime workDate;
  final double hours;
  final String? description;

  factory CreateTimeEntryRequest.fromJson(Map<String, dynamic> json) => CreateTimeEntryRequest(
        orderId: json['order_id'] as String?,
        workDate: DateTime.parse(json['work_date'] as String),
        hours: (json['hours'] as num).toDouble(),
        description: json['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'order_id': orderId,
        'work_date': _dateOnly(workDate),
        'hours': hours,
        'description': description,
      };
}

/// Aktualisiert einen Stundenerfassungs-Eintrag.
class UpdateTimeEntryRequest {
  const UpdateTimeEntryRequest({
    this.orderId,
    required this.workDate,
    required this.hours,
    this.description,
  });

  final String? orderId;
  final DateTime workDate;
  final double hours;
  final String? description;

  factory UpdateTimeEntryRequest.fromJson(Map<String, dynamic> json) => UpdateTimeEntryRequest(
        orderId: json['order_id'] as String?,
        workDate: DateTime.parse(json['work_date'] as String),
        hours: (json['hours'] as num).toDouble(),
        description: json['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'order_id': orderId,
        'work_date': _dateOnly(workDate),
        'hours': hours,
        'description': description,
      };
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
