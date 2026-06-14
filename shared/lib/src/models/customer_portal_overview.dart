import 'invoice.dart';
import 'maintenance_contract.dart';
import 'quote.dart';

/// Übersicht eines Endkunden im Kundenportal (`app_kunde`-Dashboard):
/// eigene Angebote, Rechnungen und Wartungsverträge/Abos.
class CustomerPortalOverview {
  const CustomerPortalOverview({
    required this.quotes,
    required this.invoices,
    required this.maintenanceContracts,
  });

  final List<Quote> quotes;
  final List<Invoice> invoices;
  final List<MaintenanceContract> maintenanceContracts;

  factory CustomerPortalOverview.fromJson(Map<String, dynamic> json) => CustomerPortalOverview(
        quotes: (json['quotes'] as List)
            .map((e) => Quote.fromJson(e as Map<String, dynamic>))
            .toList(),
        invoices: (json['invoices'] as List)
            .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
            .toList(),
        maintenanceContracts: (json['maintenance_contracts'] as List)
            .map((e) => MaintenanceContract.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'quotes': quotes.map((q) => q.toJson()).toList(),
        'invoices': invoices.map((i) => i.toJson()).toList(),
        'maintenance_contracts': maintenanceContracts.map((c) => c.toJson()).toList(),
      };
}
