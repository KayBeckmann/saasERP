/// Kennzahlen für die Dashboard-Übersicht eines Mandanten: offene Belege je
/// Typ, überfällige Rechnungen und die Arbeitsstunden des angemeldeten
/// Nutzers im laufenden Monat.
class DashboardSummary {
  const DashboardSummary({
    required this.openQuotes,
    required this.openOrders,
    required this.openPurchaseOrders,
    required this.openInvoices,
    required this.overdueInvoicesCount,
    required this.overdueInvoicesTotal,
    required this.monthlyHours,
  });

  /// Angebote im Status `draft`/`sent`.
  final int openQuotes;

  /// Aufträge im Status `open`/`in_progress`.
  final int openOrders;

  /// Bestellungen im Status `open`/`ordered`/`partially_delivered`.
  final int openPurchaseOrders;

  /// Rechnungen im Status `draft`/`sent`/`overdue`.
  final int openInvoices;

  /// Anzahl überfälliger, nicht bezahlter Rechnungen.
  final int overdueInvoicesCount;

  /// Summe aus `Invoice.totalDue` aller überfälligen Rechnungen.
  final double overdueInvoicesTotal;

  /// Summe der Arbeitsstunden des angemeldeten Nutzers im laufenden Monat.
  final double monthlyHours;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
        openQuotes: json['open_quotes'] as int,
        openOrders: json['open_orders'] as int,
        openPurchaseOrders: json['open_purchase_orders'] as int,
        openInvoices: json['open_invoices'] as int,
        overdueInvoicesCount: json['overdue_invoices_count'] as int,
        overdueInvoicesTotal: (json['overdue_invoices_total'] as num).toDouble(),
        monthlyHours: (json['monthly_hours'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'open_quotes': openQuotes,
        'open_orders': openOrders,
        'open_purchase_orders': openPurchaseOrders,
        'open_invoices': openInvoices,
        'overdue_invoices_count': overdueInvoicesCount,
        'overdue_invoices_total': overdueInvoicesTotal,
        'monthly_hours': monthlyHours,
      };
}
