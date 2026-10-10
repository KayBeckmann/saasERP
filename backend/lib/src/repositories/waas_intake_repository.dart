import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

/// Manual owner-supplied mail intake; all fields except the authenticated
/// tenant and actor are untrusted, including claimed sender and mailbox key.
/// The PDF remains quarantined bytes, never promoted into `documents`.
class WaasIntakeRepository {
  WaasIntakeRepository(this._pool);
  final Pool<void> _pool;

  Future<String> importMessage({
    required String tenantId,
    required String actorId,
    required String mailbox,
    required String messageKey,
    required Uint8List rawMessage,
    required String instruction,
    required String claimedFrom,
    required String claimedSubject,
    Uint8List? pdf,
    String? pdfName,
  }) async {
    if (mailbox.trim().isEmpty ||
        mailbox.length > 128 ||
        messageKey.trim().isEmpty ||
        messageKey.length > 256 ||
        rawMessage.isEmpty ||
        rawMessage.length > 2 * 1024 * 1024 ||
        instruction.length > 4000 ||
        claimedFrom.length > 512 ||
        claimedSubject.length > 512 ||
        (pdf != null &&
            (pdf.isEmpty ||
                pdf.length > 5 * 1024 * 1024 ||
                pdf.length < 5 ||
                String.fromCharCodes(pdf.take(5)) != '%PDF-')) ||
        (pdf == null && pdfName != null) ||
        (pdf != null &&
            (pdfName == null ||
                pdfName.length > 255 ||
                pdfName.trim().isEmpty))) {
      throw ArgumentError('invalid import');
    }
    final hash = sha256.convert(rawMessage).toString();
    return _pool.runTx((tx) async {
      final inserted = await tx.execute(
        Sql.named('''
        INSERT INTO waas_intake (tenant_id, mailbox, message_key, raw_sha256, raw_message,
            instruction, claimed_from, claimed_subject, pdf_bytes, pdf_name)
        VALUES (@tenant,@mailbox,@key,@hash,@raw,@instruction,@from,@subject,@pdf,@name)
        ON CONFLICT (tenant_id,mailbox,message_key) DO NOTHING RETURNING id
      '''),
        parameters: {
          'tenant': tenantId,
          'mailbox': mailbox,
          'key': messageKey,
          'hash': hash,
          'raw': rawMessage,
          'instruction': instruction,
          'from': claimedFrom,
          'subject': claimedSubject,
          'pdf': pdf,
          'name': pdfName,
        },
      );
      if (inserted.isNotEmpty) {
        final id = inserted.first[0] as String;
        await _audit(
          tx,
          tenantId,
          id,
          actorId,
          'imported',
          'Owner manual import; sender unverified',
        );
        return id;
      }
      final existing = await tx.execute(
        Sql.named('''
        SELECT id,raw_sha256,instruction,claimed_from,claimed_subject,pdf_bytes,pdf_name
        FROM waas_intake WHERE tenant_id=@tenant AND mailbox=@mailbox AND message_key=@key
      '''),
        parameters: {'tenant': tenantId, 'mailbox': mailbox, 'key': messageKey},
      );
      final row = existing.first.toColumnMap();
      final storedPdf = row['pdf_bytes'] as Uint8List?;
      if (row['raw_sha256'] != hash ||
          row['instruction'] != instruction ||
          row['claimed_from'] != claimedFrom ||
          row['claimed_subject'] != claimedSubject ||
          row['pdf_name'] != pdfName ||
          (storedPdf == null
              ? pdf != null
              : pdf == null || !_sameBytes(storedPdf, pdf))) {
        throw StateError('mailbox key collision with different payload');
      }
      return row['id'] as String;
    });
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<List<Map<String, dynamic>>> list({required String tenantId}) async {
    final rows = await _pool.execute(
      Sql.named('''
      SELECT id,mailbox,message_key,claimed_from,claimed_subject,instruction,pdf_name,
        customer_id,status,verification_note,created_at,updated_at
      FROM waas_intake WHERE tenant_id=@tenant ORDER BY created_at DESC,id DESC
    '''),
      parameters: {'tenant': tenantId},
    );
    return rows.map((r) => r.toColumnMap()).toList();
  }

  Future<Uint8List?> raw({required String tenantId, required String id}) =>
      _bytes(tenantId, id, 'raw_message');
  Future<Uint8List?> attachment({
    required String tenantId,
    required String id,
  }) => _bytes(tenantId, id, 'pdf_bytes');
  Future<Uint8List?> _bytes(String tenantId, String id, String column) async {
    final rows = await _pool.execute(
      Sql.named(
        'SELECT $column FROM waas_intake WHERE tenant_id=@tenant AND id=@id',
      ),
      parameters: {'tenant': tenantId, 'id': id},
    );
    return rows.isEmpty ? null : rows.first[0] as Uint8List?;
  }

  Future<void> associate({
    required String tenantId,
    required String id,
    required String customerId,
    required String actorId,
    required String verificationNote,
  }) async {
    if (verificationNote.trim().length < 8)
      throw ArgumentError('out-of-band verification note required');
    await _pool.runTx((tx) async {
      final customer = await tx.execute(
        Sql.named(
          'SELECT 1 FROM customers WHERE tenant_id=@tenant AND id=@customer',
        ),
        parameters: {'tenant': tenantId, 'customer': customerId},
      );
      if (customer.isEmpty) throw StateError('customer not in tenant');
      final result = await tx.execute(
        Sql.named('''
        UPDATE waas_intake SET customer_id=@customer, verification_note=@note,
          status='associated',updated_at=now() WHERE tenant_id=@tenant AND id=@id AND status='pending'
      '''),
        parameters: {
          'tenant': tenantId,
          'id': id,
          'customer': customerId,
          'note': verificationNote.trim(),
        },
      );
      if (result.affectedRows != 1) throw StateError('not pending');
      await _audit(
        tx,
        tenantId,
        id,
        actorId,
        'associated',
        verificationNote.trim(),
      );
    });
  }

  Future<void> markReviewed({
    required String tenantId,
    required String id,
    required String actorId,
    required String decisionNote,
  }) async {
    if (decisionNote.trim().length < 8)
      throw ArgumentError('decision note required');
    await _pool.runTx((tx) async {
      final result = await tx.execute(
        Sql.named('''
        UPDATE waas_intake SET status='reviewed',updated_at=now()
        WHERE tenant_id=@tenant AND id=@id AND status='associated'
      '''),
        parameters: {'tenant': tenantId, 'id': id},
      );
      if (result.affectedRows != 1) throw StateError('association required');
      await _audit(tx, tenantId, id, actorId, 'reviewed', decisionNote.trim());
    });
  }

  Future<void> _audit(
    TxSession tx,
    String tenant,
    String id,
    String actor,
    String action,
    String note,
  ) async {
    await tx.execute(
      Sql.named('''
      INSERT INTO waas_intake_audit (tenant_id,request_id,actor_id,action,note)
      VALUES (@tenant,@id,@actor,@action,@note)
    '''),
      parameters: {
        'tenant': tenant,
        'id': id,
        'actor': actor,
        'action': action,
        'note': note,
      },
    );
  }
}
