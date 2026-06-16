import 'package:saaserp_shared/saaserp_shared.dart';

import 'config.dart';
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
    required AppConfig config,
    required TenantRepository tenantRepository,
    required CustomerRepository customerRepository,
    required CustomerPortalAccountRepository portalAccountRepository,
    required UserRepository userRepository,
  })  : _emailService = emailService,
        _config = config,
        _tenantRepository = tenantRepository,
        _customerRepository = customerRepository,
        _portalAccountRepository = portalAccountRepository,
        _userRepository = userRepository;

  final EmailService _emailService;
  final AppConfig _config;
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

  /// Benachrichtigt den Endkunden im Kundenportal, dass eine Mahnung
  /// ausgestellt wurde — keine Aktion, falls kein Kunde zugeordnet ist oder
  /// kein Portal-Zugang existiert (gleiche Guard-Logik wie die anderen
  /// Customer-Methoden).
  Future<void> notifyCustomerDunning({required String tenantId, required Invoice invoice}) async {
    final customerId = invoice.customerId;
    if (customerId == null) return;

    final account = await _portalAccountRepository.findByCustomerId(
      tenantId: tenantId,
      customerId: customerId,
    );
    if (account == null) return;

    final tenant = await _tenantRepository.findById(tenantId);
    final tenantName = tenant?.name ?? 'Ihr Dienstleister';

    final levelLabel = switch (invoice.dunningLevel) {
      1 => 'Zahlungserinnerung',
      2 => '1. Mahnung',
      _ => '2. Mahnung',
    };

    await _emailService.sendMail(
      to: account.email,
      subject: '$levelLabel zu Rechnung ${invoice.invoiceNumber} — $tenantName',
      text: 'Hallo,\n\n'
          '$tenantName hat eine $levelLabel für die Rechnung ${invoice.invoiceNumber} ausgestellt.\n\n'
          'Offener Betrag: ${invoice.totalDue.toStringAsFixed(2)} EUR\n\n'
          'Bitte loggen Sie sich im Kundenportal ein, um die Rechnung einzusehen.\n\n'
          'Mit freundlichen Grüßen\n$tenantName',
    );
  }

  /// Begrüßungs-E-Mail an den Mandanten-Inhaber nach der Registrierung
  /// (M6 — Onboarding-Funnel). Enthält den App-Link zum direkten Einstieg.
  Future<void> notifyOwnerWelcome({required String email, required String companyName}) async {
    await _emailService.sendMail(
      to: email,
      subject: 'Willkommen bei saasERP — $companyName ist jetzt dabei!',
      text: 'Hallo,\n\n'
          'Ihr Unternehmen "$companyName" ist jetzt bei saasERP registriert.\n\n'
          'Sie können sich direkt einloggen und loslegen:\n'
          '${_config.appKundeUrl.replaceFirst(RegExp(r':\d+$'), ':8081')}\n\n'
          'Bei Fragen stehen wir Ihnen über das Kontaktformular zur Verfügung.\n\n'
          'Viel Erfolg!\nsaasERP',
    );
  }

  /// Leitet eine Support-Anfrage (POST /api/support/contact) an die
  /// konfigurierte [AppConfig.supportEmail] weiter. Ist [supportEmail] leer,
  /// wird nur geloggt (analog zu SMTP_HOST leer).
  Future<void> forwardSupportRequest({
    required String name,
    required String email,
    required String message,
    String? subject,
  }) async {
    final supportEmail = _config.supportEmail;
    final effectiveSubject = 'Support-Anfrage von $name: ${subject ?? '(kein Betreff)'}';
    if (supportEmail.isEmpty) {
      // ignore: avoid_print
      print('[NotificationService] Support-Anfrage von $email (kein SUPPORT_EMAIL konfiguriert): $effectiveSubject');
      return;
    }
    await _emailService.sendMail(
      to: supportEmail,
      subject: effectiveSubject,
      text: 'Von: $name <$email>\n\n$message',
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
