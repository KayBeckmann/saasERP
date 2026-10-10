import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';
import '../waas_psp.dart';

class MandateFlow {
  const MandateFlow(this.id, this.providerReference, this.url, this.status);
  final String id, providerReference, status;
  final Uri url;
  @override
  bool operator ==(Object other) =>
      other is MandateFlow &&
      id == other.id &&
      providerReference == other.providerReference &&
      url == other.url &&
      status == other.status;
  @override
  int get hashCode => Object.hash(id, providerReference, url, status);
}

class PaymentSubmission {
  const PaymentSubmission(this.id, this.providerReference, this.status);
  final String id, providerReference, status;
  @override
  bool operator ==(Object other) =>
      other is PaymentSubmission &&
      id == other.id &&
      providerReference == other.providerReference &&
      status == other.status;
  @override
  int get hashCode => Object.hash(id, providerReference, status);
}

/// No platform invoices, no customer-supplied merchant, no bank details.
class WaasPaymentRepository {
  WaasPaymentRepository(this._pool, this._psp);
  final Pool<void> _pool;
  final WaasPsp _psp;

  Future<MandateFlow> startMandate({
    required String tenantId,
    required String customerId,
  }) => _pool.runTx((tx) async {
    final merchants = await tx.execute(
      Sql.named(
        'SELECT id, credential_alias FROM waas_psp_merchants WHERE tenant_id=@t FOR UPDATE',
      ),
      parameters: {'t': tenantId},
    );
    if (merchants.isEmpty) throw StateError('merchant not configured');
    final merchant = merchants.first.toColumnMap();
    final customers = await tx.execute(
      Sql.named('SELECT 1 FROM customers WHERE id=@c AND tenant_id=@t'),
      parameters: {'c': customerId, 't': tenantId},
    );
    if (customers.isEmpty) throw StateError('customer not found');
    final existing = await tx.execute(
      Sql.named(
        "SELECT id,provider_ref,hosted_url,status FROM waas_psp_mandates WHERE tenant_id=@t AND customer_id=@c AND status!='revoked' FOR UPDATE",
      ),
      parameters: {'t': tenantId, 'c': customerId},
    );
    if (existing.isNotEmpty) {
      final m = existing.first.toColumnMap();
      return MandateFlow(
        m['id'] as String,
        m['provider_ref'] as String,
        Uri.parse(m['hosted_url'] as String),
        m['status'] as String,
      );
    }
    // Serialize on merchant row so competing requests cannot initiate two hosted flows.
    final requestId = await tx.execute(Sql('SELECT gen_random_uuid() AS id'));
    final hosted = _psp.hostedMandate(
      merchantAlias: merchant['credential_alias'] as String,
      requestId: requestId.first[0] as String,
    );
    if (hosted.url.scheme != 'https' ||
        hosted.url.userInfo.isNotEmpty ||
        hosted.providerReference.isEmpty)
      throw StateError('invalid hosted flow');
    final rows = await tx.execute(
      Sql.named(
        'INSERT INTO waas_psp_mandates (merchant_id,tenant_id,customer_id,provider_ref,hosted_url) VALUES (@m,@t,@c,@ref,@url) RETURNING id',
      ),
      parameters: {
        'm': merchant['id'],
        't': tenantId,
        'c': customerId,
        'ref': hosted.providerReference,
        'url': hosted.url.toString(),
      },
    );
    return MandateFlow(
      rows.first[0] as String,
      hosted.providerReference,
      hosted.url,
      'pending',
    );
  });

  Future<PaymentSubmission> submit({
    required String tenantId,
    required String customerId,
    required String invoiceId,
    required String mandateId,
    required int amountCents,
  }) => _pool.runTx((tx) async {
    final merchants = await tx.execute(
      Sql.named(
        'SELECT id,credential_alias FROM waas_psp_merchants WHERE tenant_id=@t FOR UPDATE',
      ),
      parameters: {'t': tenantId},
    );
    if (merchants.isEmpty) throw StateError('merchant not found');
    final merchant = merchants.first.toColumnMap();
    final invoice = await tx.execute(
      Sql.named(
        "SELECT i.status, i.customer_id FROM invoices i JOIN waas_billing_runs w ON w.invoice_id=i.id AND w.tenant_id=i.tenant_id AND w.approved_at IS NOT NULL JOIN waas_invoice_documents d ON d.invoice_id=i.id AND d.tenant_id=i.tenant_id AND d.customer_id=i.customer_id WHERE i.id=@i AND i.tenant_id=@t AND i.customer_id=@c FOR UPDATE OF i",
      ),
      parameters: {'i': invoiceId, 't': tenantId, 'c': customerId},
    );
    if (invoice.isEmpty) throw StateError('approved invoice not found');
    final existing = await tx.execute(
      Sql.named(
        'SELECT id,provider_ref,status,amount_cents,mandate_id FROM waas_psp_payments WHERE invoice_id=@i AND tenant_id=@t FOR UPDATE',
      ),
      parameters: {'i': invoiceId, 't': tenantId},
    );
    if (existing.isNotEmpty) {
      final p = existing.first.toColumnMap();
      if (p['status'] == 'returned' ||
          p['status'] == 'failed' ||
          p['amount_cents'] != amountCents ||
          p['mandate_id'] != mandateId)
        throw StateError('payment already finalized or mismatched');
      return PaymentSubmission(
        p['id'] as String,
        p['provider_ref'] as String,
        p['status'] as String,
      );
    }
    if (invoice.first[0] != 'sent') throw StateError('invoice not open');
    final mandate = await tx.execute(
      Sql.named(
        "SELECT provider_ref FROM waas_psp_mandates WHERE id=@id AND merchant_id=@m AND tenant_id=@t AND customer_id=@c AND status='active' FOR UPDATE",
      ),
      parameters: {
        'id': mandateId,
        'm': merchant['id'],
        't': tenantId,
        'c': customerId,
      },
    );
    if (mandate.isEmpty) throw StateError('active mandate not found');
    final totals = await tx.execute(
      Sql.named(
        'SELECT round(sum(quantity::numeric * unit_price::numeric * (1 + vat_rate::numeric / 100)) * 100)::integer AS cents FROM invoice_items WHERE invoice_id=@i AND tenant_id=@t',
      ),
      parameters: {'i': invoiceId, 't': tenantId},
    );
    if (amountCents <= 0 || totals.first[0] != amountCents)
      throw StateError('invoice amount mismatch');
    final requestId = await tx.execute(Sql('SELECT gen_random_uuid() AS id'));
    final ref = _psp.submit(
      merchantAlias: merchant['credential_alias'] as String,
      mandateRef: mandate.first[0] as String,
      requestId: requestId.first[0] as String,
      amountCents: amountCents,
    );
    if (ref.isEmpty) throw StateError('invalid payment reference');
    final rows = await tx.execute(
      Sql.named(
        "INSERT INTO waas_psp_payments (merchant_id,tenant_id,customer_id,mandate_id,invoice_id,provider_ref,amount_cents,status) VALUES (@m,@t,@c,@mandate,@invoice,@ref,@amount,'submitted') RETURNING id",
      ),
      parameters: {
        'm': merchant['id'],
        't': tenantId,
        'c': customerId,
        'mandate': mandateId,
        'invoice': invoiceId,
        'ref': ref,
        'amount': amountCents,
      },
    );
    return PaymentSubmission(rows.first[0] as String, ref, 'submitted');
  });

  /// Public callback may only choose an existing merchant binding; identity is
  /// authenticated from raw bytes BEFORE any state mutation. Event and transition
  /// are committed together; conflicting event IDs fail closed.
  Future<String> processWebhook({
    required String merchantId,
    required List<int> rawBody,
    required String signature,
  }) async {
    if (rawBody.length > 16384) throw const FormatException('oversized event');
    final merchants = await _pool.execute(
      Sql.named('SELECT credential_alias FROM waas_psp_merchants WHERE id=@m'),
      parameters: {'m': merchantId},
    );
    if (merchants.isEmpty) throw StateError('merchant not found');
    final event = _psp.verify(merchants.first[0] as String, rawBody, signature);
    final hash = sha256.convert(rawBody).toString();
    return _pool.runTx((tx) async {
      final merchantRows = await tx.execute(
        Sql.named(
          'SELECT id,tenant_id,credential_alias FROM waas_psp_merchants WHERE id=@m FOR UPDATE',
        ),
        parameters: {'m': merchantId},
      );
      if (merchantRows.isEmpty ||
          merchantRows.first.toColumnMap()['credential_alias'] !=
              event.merchant)
        throw StateError('merchant binding changed');
      final merchant = merchantRows.first.toColumnMap();
      final previous = await tx.execute(
        Sql.named(
          'SELECT body_sha256 FROM waas_psp_events WHERE merchant_id=@m AND provider_event_id=@e',
        ),
        parameters: {'m': merchantId, 'e': event.id},
      );
      if (previous.isNotEmpty) {
        if (previous.first[0] != hash) throw StateError('event id collision');
        return 'duplicate';
      }
      final mandates = await tx.execute(
        Sql.named(
          'SELECT id,tenant_id,customer_id,status FROM waas_psp_mandates WHERE merchant_id=@m AND tenant_id=@t AND provider_ref=@ref FOR UPDATE',
        ),
        parameters: {
          'm': merchantId,
          't': merchant['tenant_id'],
          'ref': event.mandate,
        },
      );
      if (mandates.isEmpty) throw StateError('mandate binding mismatch');
      final mandate = mandates.first.toColumnMap();
      var outcome = 'ignored';
      if (event.type == 'mandate.active' && mandate['status'] == 'pending' ||
          event.type == 'mandate.revoked' && mandate['status'] != 'revoked') {
        final status = event.type == 'mandate.active' ? 'active' : 'revoked';
        await tx.execute(
          Sql.named('UPDATE waas_psp_mandates SET status=@s WHERE id=@id'),
          parameters: {'s': status, 'id': mandate['id']},
        );
        outcome = 'applied';
      } else if (event.type.startsWith('payment.')) {
        final rows = await tx.execute(
          Sql.named(
            'SELECT id,invoice_id,status,amount_cents FROM waas_psp_payments WHERE merchant_id=@m AND tenant_id=@t AND customer_id=@c AND mandate_id=@mandate AND provider_ref=@ref FOR UPDATE',
          ),
          parameters: {
            'm': merchantId,
            't': merchant['tenant_id'],
            'c': mandate['customer_id'],
            'mandate': mandate['id'],
            'ref': event.payment,
          },
        );
        if (rows.isEmpty) throw StateError('payment binding mismatch');
        final payment = rows.first.toColumnMap();
        if (event.customer != mandate['customer_id'] ||
            event.invoice != payment['invoice_id'] ||
            event.amountCents != payment['amount_cents']) {
          throw StateError('event customer/invoice/amount mismatch');
        }
        final old = payment['status'];
        String? next;
        if (event.type == 'payment.settled' && old == 'submitted')
          next = 'settled';
        if (event.type == 'payment.failed' && old == 'submitted')
          next = 'failed';
        if (event.type == 'payment.returned' &&
            (old == 'settled' || old == 'submitted'))
          next = 'returned';
        if (next != null) {
          await tx.execute(
            Sql.named('UPDATE waas_psp_payments SET status=@s WHERE id=@id'),
            parameters: {'s': next, 'id': payment['id']},
          );
          if (next == 'settled' || next == 'returned') {
            await tx.execute(
              Sql.named(
                'UPDATE invoices SET status=@s WHERE id=@i AND tenant_id=@t AND customer_id=@c',
              ),
              parameters: {
                's': next == 'settled' ? 'paid' : 'sent',
                'i': payment['invoice_id'],
                't': merchant['tenant_id'],
                'c': mandate['customer_id'],
              },
            );
          }
          outcome = 'applied';
        }
      }
      await tx.execute(
        Sql.named(
          'INSERT INTO waas_psp_events (merchant_id,provider_event_id,body_sha256,event_type,outcome) VALUES (@m,@e,@hash,@type,@outcome)',
        ),
        parameters: {
          'm': merchantId,
          'e': event.id,
          'hash': hash,
          'type': event.type,
          'outcome': outcome,
        },
      );
      return outcome;
    });
  }
}
