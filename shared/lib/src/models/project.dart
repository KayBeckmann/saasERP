/// Status eines Projekts.
enum ProjectStatus {
  open,
  completed,
  cancelled;

  String toJson() => name;

  static ProjectStatus fromJson(String value) => ProjectStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => ProjectStatus.open,
      );
}

/// Projekt eines Mandanten — bündelt optional mehrere Aufträge, Bestellungen
/// und Stundenerfassungen (Verhältnis Projekt ↔ Auftrag ist 1:n, ein Projekt
/// ist für einen Auftrag nicht verpflichtend). `projectNumber` wird über den
/// Nummernkreis "project" (Prefix "P") vergeben.
class Project {
  const Project({
    required this.id,
    required this.tenantId,
    required this.projectNumber,
    required this.name,
    this.customerId,
    this.status = ProjectStatus.open,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String projectNumber;
  final String name;
  final String? customerId;
  final ProjectStatus status;
  final String? notes;
  final DateTime createdAt;

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        projectNumber: json['project_number'] as String,
        name: json['name'] as String,
        customerId: json['customer_id'] as String?,
        status: ProjectStatus.fromJson(json['status'] as String),
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'project_number': projectNumber,
        'name': name,
        'customer_id': customerId,
        'status': status.toJson(),
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Legt ein neues Projekt an — `project_number` wird serverseitig vergeben.
class CreateProjectRequest {
  const CreateProjectRequest({
    this.customerId,
    required this.name,
    this.notes,
  });

  final String? customerId;
  final String name;
  final String? notes;

  factory CreateProjectRequest.fromJson(Map<String, dynamic> json) => CreateProjectRequest(
        customerId: json['customer_id'] as String?,
        name: json['name'] as String,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'name': name,
        'notes': notes,
      };
}

/// Aktualisiert ein Projekt — `project_number` bleibt unverändert.
class UpdateProjectRequest {
  const UpdateProjectRequest({
    this.customerId,
    required this.name,
    this.status = ProjectStatus.open,
    this.notes,
  });

  final String? customerId;
  final String name;
  final ProjectStatus status;
  final String? notes;

  factory UpdateProjectRequest.fromJson(Map<String, dynamic> json) => UpdateProjectRequest(
        customerId: json['customer_id'] as String?,
        name: json['name'] as String,
        status: ProjectStatus.fromJson(json['status'] as String),
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'name': name,
        'status': status.toJson(),
        'notes': notes,
      };
}
