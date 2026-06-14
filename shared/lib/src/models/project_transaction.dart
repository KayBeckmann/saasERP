/// Art einer Projekt-Transaktion ohne eigenen Beleg.
enum ProjectTransactionKind {
  income,
  expense;

  String toJson() => name;

  static ProjectTransactionKind fromJson(String value) => ProjectTransactionKind.values.firstWhere(
        (kind) => kind.name == value,
        orElse: () => ProjectTransactionKind.expense,
      );
}

/// Sonstige Einnahme/Ausgabe eines Projekts ohne eigenen Beleg (z. B.
/// Zuschüsse, Spesen) — fließt in die Gewinn/Verlust-Übersicht ein.
class ProjectTransaction {
  const ProjectTransaction({
    required this.id,
    required this.tenantId,
    required this.projectId,
    required this.kind,
    required this.description,
    required this.amount,
    required this.transactionDate,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String projectId;
  final ProjectTransactionKind kind;
  final String description;
  final double amount;
  final DateTime transactionDate;
  final DateTime createdAt;

  factory ProjectTransaction.fromJson(Map<String, dynamic> json) => ProjectTransaction(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        projectId: json['project_id'] as String,
        kind: ProjectTransactionKind.fromJson(json['kind'] as String),
        description: json['description'] as String,
        amount: (json['amount'] as num).toDouble(),
        transactionDate: DateTime.parse(json['transaction_date'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'project_id': projectId,
        'kind': kind.toJson(),
        'description': description,
        'amount': amount,
        'transaction_date': _dateOnly(transactionDate),
        'created_at': createdAt.toIso8601String(),
      };
}

/// Legt eine neue Projekt-Transaktion an.
class CreateProjectTransactionRequest {
  const CreateProjectTransactionRequest({
    required this.kind,
    required this.description,
    required this.amount,
    required this.transactionDate,
  });

  final ProjectTransactionKind kind;
  final String description;
  final double amount;
  final DateTime transactionDate;

  factory CreateProjectTransactionRequest.fromJson(Map<String, dynamic> json) =>
      CreateProjectTransactionRequest(
        kind: ProjectTransactionKind.fromJson(json['kind'] as String),
        description: json['description'] as String,
        amount: (json['amount'] as num).toDouble(),
        transactionDate: DateTime.parse(json['transaction_date'] as String),
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.toJson(),
        'description': description,
        'amount': amount,
        'transaction_date': _dateOnly(transactionDate),
      };
}

/// Aktualisiert eine Projekt-Transaktion.
class UpdateProjectTransactionRequest {
  const UpdateProjectTransactionRequest({
    required this.kind,
    required this.description,
    required this.amount,
    required this.transactionDate,
  });

  final ProjectTransactionKind kind;
  final String description;
  final double amount;
  final DateTime transactionDate;

  factory UpdateProjectTransactionRequest.fromJson(Map<String, dynamic> json) =>
      UpdateProjectTransactionRequest(
        kind: ProjectTransactionKind.fromJson(json['kind'] as String),
        description: json['description'] as String,
        amount: (json['amount'] as num).toDouble(),
        transactionDate: DateTime.parse(json['transaction_date'] as String),
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.toJson(),
        'description': description,
        'amount': amount,
        'transaction_date': _dateOnly(transactionDate),
      };
}

/// Gewinn/Verlust-Übersicht eines Projekts — Einnahmen aus Rechnungen
/// verknüpfter Aufträge plus sonstige Einnahmen, Ausgaben aus Bestellungen
/// plus sonstige Ausgaben, sowie Stundenkosten (erfasste Stunden × hinterlegter
/// Stundensatz). Alle Beträge netto (ohne MwSt.).
class ProjectProfitLoss {
  const ProjectProfitLoss({
    required this.invoicedIncome,
    required this.otherIncome,
    required this.purchaseExpenses,
    required this.otherExpenses,
    required this.laborHours,
    required this.hourlyRate,
  });

  /// Netto-Summe aller Rechnungspositionen von Rechnungen, die aus
  /// Aufträgen dieses Projekts erzeugt wurden.
  final double invoicedIncome;

  /// Summe der sonstigen Einnahmen ([ProjectTransactionKind.income]).
  final double otherIncome;

  /// Netto-Summe aller Bestellungen, die diesem Projekt zugeordnet sind.
  final double purchaseExpenses;

  /// Summe der sonstigen Ausgaben ([ProjectTransactionKind.expense]).
  final double otherExpenses;

  /// Summe der erfassten Stunden, die diesem Projekt zugeordnet sind.
  final double laborHours;

  /// Stundensatz des Mandanten zur Verrechnung von [laborHours].
  final double hourlyRate;

  double get totalIncome => invoicedIncome + otherIncome;

  double get laborCost => laborHours * hourlyRate;

  double get totalExpenses => purchaseExpenses + otherExpenses + laborCost;

  double get profit => totalIncome - totalExpenses;

  factory ProjectProfitLoss.fromJson(Map<String, dynamic> json) => ProjectProfitLoss(
        invoicedIncome: (json['invoiced_income'] as num).toDouble(),
        otherIncome: (json['other_income'] as num).toDouble(),
        purchaseExpenses: (json['purchase_expenses'] as num).toDouble(),
        otherExpenses: (json['other_expenses'] as num).toDouble(),
        laborHours: (json['labor_hours'] as num).toDouble(),
        hourlyRate: (json['hourly_rate'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'invoiced_income': invoicedIncome,
        'other_income': otherIncome,
        'purchase_expenses': purchaseExpenses,
        'other_expenses': otherExpenses,
        'labor_hours': laborHours,
        'hourly_rate': hourlyRate,
      };
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
