import 'package:saaserp_shared/saaserp_shared.dart';

import 'email_service.dart';
import 'repositories/customer_portal_account_repository.dart';
import 'repositories/customer_repository.dart';
import 'repositories/tenant_repository.dart';
import 'repositories/user_repository.dart';

/// Bündelt die E-Mail-Benachrichtigungen bei neuem Angebot/neuer Rechnung
/// (an den Endkunden im Kundenportal) und bei Status-Änderungen durch den
/// Endkunden (an den Mandanten-Inhaber).
///
/// Versandfehler werden von [EmailService] selbst abgefangen und geloggt —
/// eine fehlgeschlagene Benachrichtigung darf den auslösenden API-Request
/// nie scheitern lassen.
class NotificationService {
  NotificationService({
    required EmailService emailService,
    required TenantRepository tenantRepository,
    required CustomerRepository customerRepository,
    required CustomerPortalAccountRepository portalAccountRepository,
    required UserRepository userRepository,
  })  : _emailService = emailService,
        _tenantRepository = tenantRepository,
        _customerRepository = customerRepository,
        _portalAccountRepository = portalAccountRepository,
        _userRepository = userRepository;

  final EmailService _emailService;
  final TenantRepository _tenantRepository;
  final CustomerRepository _customerRepository;
  final CustomerPortalAccountRepository _portalAccountRepository;
  final UserRepository _userRepository;

  /// Benachrichtigt den Endkunden im Kundenportal über ein neu versendetes
  /// Angebot — keine Aktion, falls kein Kunde zugeordnet ist oder kein
  /// Portal-Zugang existiert.
  Future<void> notifyCustomerNewQuote({required String tenantId, required Quote quote}) async {
    final customerId = quote.customerId;
    if (customerId == null) return;

    final account = await _portalAccountRepository.findByCustomerId(
      tenantId: tenantId,
      customerId: customerId,
    );
    if (account == null) return;

    final tenant = await _tenantRepository.findById(tenantId);
    final tenantName = tenant?.name ?? 'Ihr Dienstleister';

    await _emailService.sendMail(
      to: account.email,
      subject: 'Neues Angebot ${quote.quoteNumber} von $tenantName',
      text: 'Hallo,\n\n'
          '$tenantName hat ein neues Angebot für Sie erstellt: '
          '${quote.quoteNumber} – ${quote.title}.\n\n'
          'Bitte loggen Sie sich im Kundenportal ein, um es einzusehen und zu beantworten.\n\n'
          'Mit freundlichen Grüßen\n$tenantName',
    );
  }

  /// Benachrichtigt den Endkunden im Kundenportal über eine neu versendete
  /// Rechnung — keine Aktion, falls kein Kunde zugeordnet ist oder kein
  /// Portal-Zugang existiert.
  Future<void> notifyCustomerNewInvoice({required String tenantId, required Invoice invoice}) async {
    final customerId = invoice.customerId;
    if (customerId == null) return;

    final account = await _portalAccountRepository.findByCustomerId(
      tenantId: tenantId,
      customerId: customerId,
    );
    if (account == null) return;

    final tenant = await _tenantRepository.findById(tenantId);
    final tenantName = tenant?.name ?? 'Ihr Dienstleister';

    await _emailService.sendMail(
      to: account.email,
      subject: 'Neue Rechnung ${invoice.invoiceNumber} von $tenantName',
      text: 'Hallo,\n\n'
          '$tenantName hat eine neue Rechnung für Sie erstellt: '
          '${invoice.invoiceNumber} – ${invoice.title}.\n\n'
          'Bitte loggen Sie sich im Kundenportal ein, um sie einzusehen.\n\n'
          'Mit freundlichen Grüßen\n$tenantName',
    );
  }

  /// Benachrichtigt den Mandanten-Inhaber, wenn ein Endkunde im
  /// Kundenportal über ein Angebot entschieden hat (angenommen/abgelehnt) —
  /// keine Aktion, falls kein Owner-Zugang existiert.
  Future<void> notifyOwnerQuoteDecision({required String tenantId, required Quote quote}) async {
    final ownerEmail = await _userRepository.findOwnerEmail(tenantId);
    if (ownerEmail == null) return;

    final customerId = quote.customerId;
    final customer =
        customerId == null ? null : await _customerRepository.findById(tenantId: tenantId, id: customerId);
    final customerName = customer?.name ?? 'Ein Kunde';

    final decisionText = quote.status == QuoteStatus.accepted ? 'angenommen' : 'abgelehnt';
    final comment = quote.customerComment?.trim();

    await _emailService.sendMail(
      to: ownerEmail,
      subject: 'Angebot ${quote.quoteNumber} wurde $decisionText',
      text: 'Hallo,\n\n'
          '$customerName hat das Angebot ${quote.quoteNumber} – ${quote.title} $decisionText.'
          '${comment != null && comment.isNotEmpty ? '\n\nKommentar: $comment' : ''}\n\n'
          'Mit freundlichen Grüßen\nsaasERP',
    );
  }
}
