import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Provider boundary: implementation owns hosted collection and webhook verification.
/// Never accept bank details through the ERP API.
abstract class WaasPsp {
  HostedMandate hostedMandate({
    required String merchantAlias,
    required String requestId,
  });
  String submit({
    required String merchantAlias,
    required String mandateRef,
    required String requestId,
    required int amountCents,
  });
  PspEvent verify(String merchantAlias, List<int> rawBody, String signature);
}

class HostedMandate {
  const HostedMandate(this.providerReference, this.url);
  final String providerReference;
  final Uri url;
}

class PspEvent {
  const PspEvent(this.id, this.merchant, this.type, this.mandate, this.payment, this.customer, this.invoice, this.amountCents);
  final String id, merchant, type, mandate;
  final String? payment;
  final String? customer, invoice;
  final int? amountCents;
}

/// Test-only simulator. An .invalid URL cannot capture any banking information.
/// A production provider must supply its own independent verifier and hosted API.
class FakeWaasPsp implements WaasPsp {
  FakeWaasPsp(this._secrets);
  final Map<String, String> _secrets;

  String _ref() => List<int>.generate(
    24,
    (_) => Random.secure().nextInt(256),
  ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  void _configured(String alias) {
    if (_secrets[alias] == null || _secrets[alias]!.isEmpty)
      throw StateError('merchant disabled');
  }

  @override
  HostedMandate hostedMandate({
    required String merchantAlias,
    required String requestId,
  }) {
    _configured(merchantAlias);
    final ref = 'fake_m_${_ref()}';
    return HostedMandate(ref, Uri.https('sandbox.invalid', '/mandates/$ref'));
  }

  @override
  String submit({
    required String merchantAlias,
    required String mandateRef,
    required String requestId,
    required int amountCents,
  }) {
    _configured(merchantAlias);
    if (amountCents <= 0) throw ArgumentError.value(amountCents);
    return 'fake_p_${_ref()}'; // submission is NOT settlement
  }

  String signForTest(String alias, List<int> body, DateTime time) {
    _configured(alias);
    final timestamp = time.toUtc().millisecondsSinceEpoch ~/ 1000;
    final mac = Hmac(
      sha256,
      utf8.encode(_secrets[alias]!),
    ).convert([...utf8.encode('$timestamp.'), ...body]).toString();
    return '$timestamp.$mac';
  }

  @override
  PspEvent verify(String merchantAlias, List<int> rawBody, String signature) {
    _configured(merchantAlias);
    final match = RegExp(r'^(\d{10})\.([0-9a-f]{64})$').firstMatch(signature);
    if (match == null) throw const FormatException('invalid signature');
    final seconds = int.parse(match.group(1)!);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    if ((now - seconds).abs() > 300)
      throw const FormatException('expired signature');
    final expected = signForTest(
      merchantAlias,
      rawBody,
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
    ).split('.')[1];
    final a = utf8.encode(expected), b = utf8.encode(match.group(2)!);
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    if (difference != 0) throw const FormatException('invalid signature');
    final decoded = jsonDecode(utf8.decode(rawBody));
    if (decoded is! Map<String, dynamic>)
      throw const FormatException('invalid event');
    String field(String key) {
      final value = decoded[key];
      if (value is! String || value.isEmpty || value.length > 256)
        throw const FormatException('invalid event field');
      return value;
    }

    final merchant = field('merchant');
    if (merchant != merchantAlias)
      throw const FormatException('merchant mismatch');
    final type = field('type');
    if (!{
      'mandate.active',
      'mandate.revoked',
      'payment.settled',
      'payment.failed',
      'payment.returned',
    }.contains(type))
      throw const FormatException('unsupported event');
    final payment = decoded['payment'];
    if (type.startsWith('payment.') &&
        (payment is! String || payment.isEmpty || payment.length > 256))
      throw const FormatException('missing payment');
    if (!type.startsWith('payment.') && payment != null)
      throw const FormatException('unexpected payment');
    final customer = type.startsWith('payment.') ? field('customer') : null;
    final invoice = type.startsWith('payment.') ? field('invoice') : null;
    final amount = decoded['amount_cents'];
    if (type.startsWith('payment.') && (amount is! int || amount <= 0))
      throw const FormatException('invalid payment amount');
    return PspEvent(
      field('id'),
      merchant,
      type,
      field('mandate'),
      payment as String?,
      customer,
      invoice,
      amount as int?,
    );
  }
}

class DisabledWaasPsp implements WaasPsp {
  Never _disabled() => throw StateError('PSP not configured');
  @override
  HostedMandate hostedMandate({
    required String merchantAlias,
    required String requestId,
  }) => _disabled();
  @override
  String submit({
    required String merchantAlias,
    required String mandateRef,
    required String requestId,
    required int amountCents,
  }) => _disabled();
  @override
  PspEvent verify(String merchantAlias, List<int> rawBody, String signature) =>
      _disabled();
}
