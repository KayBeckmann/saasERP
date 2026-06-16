import 'package:saaserp_shared/saaserp_shared.dart';

/// Generiert ein ZUGFeRD 2.1 / Factur-X Basic Profile XML für die gegebene
/// Rechnung. Das XML ist EN-16931-konform und kann direkt in Buchhaltungs-
/// Software importiert oder als Anhang in ein PDF/A-3b-Dokument eingebettet
/// werden.
///
/// Für XRechnung (B2G): `customer.leitwegId` wird als `BuyerReference`
/// übernommen, wenn gesetzt — gesetzliche Pflicht bei öffentlichen
/// Auftraggebern ab 2025.
String buildZugferdXml({
  required Invoice invoice,
  required Tenant tenant,
  Customer? customer,
}) {
  final issueDate = _fmtDate(invoice.createdAt);
  final vatGroups = _groupVat(invoice.items);
  final leitwegId = customer?.leitwegId;

  return '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<rsm:CrossIndustryInvoice\n'
      '  xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100"\n'
      '  xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100"\n'
      '  xmlns:udt="urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100">\n'
      '\n'
      '  <rsm:ExchangedDocumentContext>\n'
      '    <ram:GuidelineSpecifiedDocumentContextParameter>\n'
      '      <ram:ID>urn:cen.eu:en16931:2017#compliant#urn:factur-x.eu:1p0:basic</ram:ID>\n'
      '    </ram:GuidelineSpecifiedDocumentContextParameter>\n'
      '  </rsm:ExchangedDocumentContext>\n'
      '\n'
      '  <rsm:ExchangedDocument>\n'
      '    <ram:ID>${_esc(invoice.invoiceNumber)}</ram:ID>\n'
      '    <ram:TypeCode>380</ram:TypeCode>\n'
      '    <ram:IssueDateTime>\n'
      '      <udt:DateTimeString format="102">$issueDate</udt:DateTimeString>\n'
      '    </ram:IssueDateTime>\n'
      '  </rsm:ExchangedDocument>\n'
      '\n'
      '  <rsm:SupplyChainTradeTransaction>\n'
      '${_lineItems(invoice.items)}'
      '    <ram:ApplicableHeaderTradeAgreement>\n'
      '${leitwegId != null ? '      <ram:BuyerReference>${_esc(leitwegId)}</ram:BuyerReference>\n' : ''}'
      '      <ram:SellerTradeParty>\n'
      '        <ram:Name>${_esc(tenant.name)}</ram:Name>\n'
      '        <ram:PostalTradeAddress>\n'
      '${tenant.companyAddress != null ? '          <ram:LineOne>${_esc(tenant.companyAddress!)}</ram:LineOne>\n' : ''}'
      '          <ram:CountryID>DE</ram:CountryID>\n'
      '        </ram:PostalTradeAddress>\n'
      '${_sellerTaxBlock(tenant.companyTaxId)}'
      '      </ram:SellerTradeParty>\n'
      '      <ram:BuyerTradeParty>\n'
      '        <ram:Name>${_esc(customer?.name ?? '')}</ram:Name>\n'
      '        <ram:PostalTradeAddress>\n'
      '${customer?.address != null ? '          <ram:LineOne>${_esc(customer!.address!)}</ram:LineOne>\n' : ''}'
      '          <ram:CountryID>DE</ram:CountryID>\n'
      '        </ram:PostalTradeAddress>\n'
      '      </ram:BuyerTradeParty>\n'
      '    </ram:ApplicableHeaderTradeAgreement>\n'
      '\n'
      '    <ram:ApplicableHeaderTradeDelivery/>\n'
      '\n'
      '    <ram:ApplicableHeaderTradeSettlement>\n'
      '      <ram:PaymentReference>${_esc(invoice.invoiceNumber)}</ram:PaymentReference>\n'
      '      <ram:InvoiceCurrencyCode>EUR</ram:InvoiceCurrencyCode>\n'
      '${_headerVatBlocks(vatGroups)}'
      '${invoice.dueDate != null ? '      <ram:SpecifiedTradePaymentTerms>\n'
          '        <ram:DueDateDateTime>\n'
          '          <udt:DateTimeString format="102">${_fmtDate(invoice.dueDate!)}</udt:DateTimeString>\n'
          '        </ram:DueDateDateTime>\n'
          '      </ram:SpecifiedTradePaymentTerms>\n' : ''}'
      '      <ram:SpecifiedTradeSettlementHeaderMonetarySummation>\n'
      '        <ram:LineTotalAmount>${_fmtAmt(invoice.totalNet)}</ram:LineTotalAmount>\n'
      '        <ram:TaxBasisTotalAmount>${_fmtAmt(invoice.totalNet)}</ram:TaxBasisTotalAmount>\n'
      '        <ram:TaxTotalAmount currencyID="EUR">${_fmtAmt(invoice.totalGross - invoice.totalNet)}</ram:TaxTotalAmount>\n'
      '        <ram:GrandTotalAmount>${_fmtAmt(invoice.totalGross)}</ram:GrandTotalAmount>\n'
      '        <ram:DuePayableAmount>${_fmtAmt(invoice.amountDue)}</ram:DuePayableAmount>\n'
      '      </ram:SpecifiedTradeSettlementHeaderMonetarySummation>\n'
      '    </ram:ApplicableHeaderTradeSettlement>\n'
      '  </rsm:SupplyChainTradeTransaction>\n'
      '</rsm:CrossIndustryInvoice>';
}

/// Grouped VAT block: vatRate → (basisAmount, calculatedAmount)
Map<double, ({double basis, double calculated})> _groupVat(List<InvoiceItem> items) {
  final map = <double, double>{};
  for (final item in items) {
    map[item.vatRate] = (map[item.vatRate] ?? 0) + item.totalNet;
  }
  return map.map((rate, basis) => MapEntry(rate, (basis: basis, calculated: basis * rate / 100)));
}

String _lineItems(List<InvoiceItem> items) {
  final buf = StringBuffer();
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final unitCode = _unitCode(item.unit);
    final categoryCode = item.vatRate == 0 ? 'Z' : 'S';
    buf.write(
      '    <ram:IncludedSupplyChainTradeLineItem>\n'
      '      <ram:AssociatedDocumentLineDocument>\n'
      '        <ram:LineID>${i + 1}</ram:LineID>\n'
      '      </ram:AssociatedDocumentLineDocument>\n'
      '      <ram:SpecifiedTradeProduct>\n'
      '        <ram:Name>${_esc(item.description)}</ram:Name>\n'
      '      </ram:SpecifiedTradeProduct>\n'
      '      <ram:SpecifiedLineTradeAgreement>\n'
      '        <ram:NetPriceProductTradePrice>\n'
      '          <ram:ChargeAmount>${_fmtAmt(item.unitPrice)}</ram:ChargeAmount>\n'
      '        </ram:NetPriceProductTradePrice>\n'
      '      </ram:SpecifiedLineTradeAgreement>\n'
      '      <ram:SpecifiedLineTradeDelivery>\n'
      '        <ram:BilledQuantity unitCode="$unitCode">${_fmtQty(item.quantity)}</ram:BilledQuantity>\n'
      '      </ram:SpecifiedLineTradeDelivery>\n'
      '      <ram:SpecifiedLineTradeSettlement>\n'
      '        <ram:ApplicableTradeTax>\n'
      '          <ram:TypeCode>VAT</ram:TypeCode>\n'
      '          <ram:CategoryCode>$categoryCode</ram:CategoryCode>\n'
      '          <ram:RateApplicablePercent>${_fmtAmt(item.vatRate)}</ram:RateApplicablePercent>\n'
      '        </ram:ApplicableTradeTax>\n'
      '        <ram:SpecifiedTradeSettlementLineMonetarySummation>\n'
      '          <ram:LineTotalAmount>${_fmtAmt(item.totalNet)}</ram:LineTotalAmount>\n'
      '        </ram:SpecifiedTradeSettlementLineMonetarySummation>\n'
      '      </ram:SpecifiedLineTradeSettlement>\n'
      '    </ram:IncludedSupplyChainTradeLineItem>\n',
    );
  }
  return buf.toString();
}

String _headerVatBlocks(Map<double, ({double basis, double calculated})> groups) {
  final buf = StringBuffer();
  for (final entry in groups.entries) {
    final rate = entry.key;
    final g = entry.value;
    final categoryCode = rate == 0 ? 'Z' : 'S';
    buf.write(
      '      <ram:ApplicableTradeTax>\n'
      '        <ram:CalculatedAmount>${_fmtAmt(g.calculated)}</ram:CalculatedAmount>\n'
      '        <ram:TypeCode>VAT</ram:TypeCode>\n'
      '        <ram:BasisAmount>${_fmtAmt(g.basis)}</ram:BasisAmount>\n'
      '        <ram:CategoryCode>$categoryCode</ram:CategoryCode>\n'
      '        <ram:RateApplicablePercent>${_fmtAmt(rate)}</ram:RateApplicablePercent>\n'
      '      </ram:ApplicableTradeTax>\n',
    );
  }
  return buf.toString();
}

String _sellerTaxBlock(String? taxId) {
  if (taxId == null || taxId.trim().isEmpty) return '';
  // USt-IdNr. starts with two uppercase letters (e.g. "DE123456789") → schemeID VA
  // Steuernummer (e.g. "123/456/789") → schemeID FC
  final trimmed = taxId.trim();
  final isVatId = trimmed.length >= 2 &&
      RegExp('^[A-Z]{2}').hasMatch(trimmed);
  final schemeId = isVatId ? 'VA' : 'FC';
  return '        <ram:SpecifiedTaxRegistration>\n'
      '          <ram:ID schemeID="$schemeId">${_esc(trimmed)}</ram:ID>\n'
      '        </ram:SpecifiedTaxRegistration>\n';
}

/// UN/ECE Rec 20 unit code mapping from common German free-text units.
String _unitCode(String? unit) {
  if (unit == null) return 'C62';
  final u = unit.trim().toLowerCase();
  return switch (u) {
    'h' || 'std' || 'std.' || 'stunde' || 'stunden' || 'hour' || 'hours' => 'HUR',
    'm²' || 'm2' || 'qm' => 'MTK',
    'm' || 'lm' => 'MTR',
    'kg' => 'KGM',
    'g' => 'GRM',
    'l' || 'liter' || 'litre' => 'LTR',
    'km' => 'KMT',
    'stk' || 'stück' || 'st' || 'st.' || 'stk.' => 'C62',
    _ => 'C62',
  };
}

/// YYYYMMDD format for ZUGFeRD dates (format code 102).
String _fmtDate(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y$m$d';
}

/// Two decimal places for monetary amounts.
String _fmtAmt(double v) => v.toStringAsFixed(2);

/// Quantity: no trailing zero for whole numbers (e.g. "1" not "1.00").
String _fmtQty(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(4);

/// XML-escapes text content.
String _esc(String v) => v
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
