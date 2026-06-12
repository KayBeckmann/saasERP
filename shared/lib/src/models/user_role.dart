/// Rollen innerhalb eines Mandanten (siehe Roadmap M1 — einfache Rollenlogik).
enum UserRole {
  owner,
  employee;

  String toJson() => name;

  static UserRole fromJson(String value) => UserRole.values.firstWhere(
        (role) => role.name == value,
        orElse: () => UserRole.employee,
      );
}
