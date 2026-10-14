import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

import '../tenant_encryption_service.dart';

const _table = 'tenants';

/// `company_address`, `company_tax_id` und `company_iban` sind pro Mandant
/// feldverschlüsselt (AEAD, RF1) — Firmenadresse/Steuer-ID/IBAN sind
/// sensible Geschäftsdaten.
class TenantRepository {
  TenantRepository(this._pool, this._encryptionService);

  final Pool<void> _pool;
  final TenantEncryptionService _encryptionService;

  static const _columns = 'id, name, created_at, branding_color, '
      'company_address, company_tax_id, company_iban, logo_url, '
      'default_vat_rate, reduced_vat_rate, '
      'dunning_fee_level1, dunning_fee_level2, dunning_fee_level3, '
      'default_hourly_rate';

  /// Legt den Mandanten an. Firmendaten (Adresse/Steuer-ID/IBAN) werden erst
  /// über [updateConfig] gesetzt, nachdem `TenantEncryptionService.
  /// provisionTenant` bei der Registrierung den DEK angelegt hat.
  Future<Tenant> create(String name) async {
    final result = await _pool.execute(
      Sql.named('INSERT INTO tenants (name) VALUES (@name) RETURNING $_columns'),
      parameters: {'name': name},
    );
    // Noch kein DEK vorhanden (provisionTenant läuft erst danach) — company_*
    // ist zu diesem Zeitpunkt ohnehin immer NULL, daher unproblematisch ohne
    // Crypto zu lesen.
    return _fromRowNoSecrets(result.first.toColumnMap());
  }

  /// Alle Mandanten — nur für den Plattform-Admin (Abo-Verwaltung, M3).
  Future<List<Tenant>> listAll() async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM tenants ORDER BY created_at ASC'),
    );
    final tenants = <Tenant>[];
    for (final row in result) {
      tenants.add(await _fromRow(row.toColumnMap()));
    }
    return tenants;
  }

  Future<Tenant?> findById(String id) async {
    final result = await _pool.execute(
      Sql.named('SELECT $_columns FROM tenants WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return _fromRow(result.first.toColumnMap());
  }

  /// Setzt die Branding-Farbe des Mandanten (`null` = generisches Theme).
  Future<Tenant> updateBranding({
    required String tenantId,
    required String? brandingColor,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        'UPDATE tenants SET branding_color = @branding_color '
        'WHERE id = @id '
        'RETURNING $_columns',
      ),
      parameters: {'id': tenantId, 'branding_color': brandingColor},
    );
    return _fromRow(result.first.toColumnMap());
  }

  /// Aktualisiert die Mandanten-Konfiguration (Firmendaten, Logo, Steuersätze).
  Future<Tenant> updateConfig({
    required String tenantId,
    required UpdateTenantConfigRequest config,
  }) async {
    final crypto = await _encryptionService.forTenant(tenantId);
    final result = await _pool.execute(
      Sql.named(
        'UPDATE tenants SET '
        'company_address = @company_address, '
        'company_tax_id = @company_tax_id, '
        'company_iban = @company_iban, '
        'logo_url = @logo_url, '
        'default_vat_rate = @default_vat_rate, '
        'reduced_vat_rate = @reduced_vat_rate, '
        'dunning_fee_level1 = @dunning_fee_level1, '
        'dunning_fee_level2 = @dunning_fee_level2, '
        'dunning_fee_level3 = @dunning_fee_level3, '
        'default_hourly_rate = @default_hourly_rate '
        'WHERE id = @id '
        'RETURNING $_columns',
      ),
      parameters: {
        'id': tenantId,
        'company_address': crypto.encryptField(
          table: _table,
          recordId: tenantId,
          field: 'company_address',
          value: config.companyAddress,
        ),
        'company_tax_id': crypto.encryptField(
          table: _table,
          recordId: tenantId,
          field: 'company_tax_id',
          value: config.companyTaxId,
        ),
        'company_iban': crypto.encryptField(
          table: _table,
          recordId: tenantId,
          field: 'company_iban',
          value: config.companyIban,
        ),
        'logo_url': config.logoUrl,
        'default_vat_rate': config.defaultVatRate,
        'reduced_vat_rate': config.reducedVatRate,
        'dunning_fee_level1': config.dunningFeeLevel1,
        'dunning_fee_level2': config.dunningFeeLevel2,
        'dunning_fee_level3': config.dunningFeeLevel3,
        'default_hourly_rate': config.defaultHourlyRate,
      },
    );
    return _fromRow(result.first.toColumnMap());
  }

  Future<Tenant> _fromRow(Map<String, dynamic> row) async {
    final tenantId = row['id'] as String;
    String? companyAddress;
    String? companyTaxId;
    String? companyIban;
    // Noch nie konfiguriert (alle drei NULL) -> kein Entschlüsseln nötig;
    // vermeidet einen DEK-Fetch für jeden Mandanten ohne Firmendaten.
    if (row['company_address'] != null || row['company_tax_id'] != null || row['company_iban'] != null) {
      final crypto = await _encryptionService.forTenant(tenantId);
      companyAddress = crypto.decryptField(
        table: _table,
        recordId: tenantId,
        field: 'company_address',
        value: row['company_address'] as String?,
      );
      companyTaxId = crypto.decryptField(
        table: _table,
        recordId: tenantId,
        field: 'company_tax_id',
        value: row['company_tax_id'] as String?,
      );
      companyIban = crypto.decryptField(
        table: _table,
        recordId: tenantId,
        field: 'company_iban',
        value: row['company_iban'] as String?,
      );
    }
    return Tenant(
      id: tenantId,
      name: row['name'] as String,
      createdAt: (row['created_at'] as DateTime).toUtc(),
      brandingColor: row['branding_color'] as String?,
      companyAddress: companyAddress,
      companyTaxId: companyTaxId,
      companyIban: companyIban,
      logoUrl: row['logo_url'] as String?,
      defaultVatRate: (row['default_vat_rate'] as num).toDouble(),
      reducedVatRate: (row['reduced_vat_rate'] as num).toDouble(),
      dunningFeeLevel1: (row['dunning_fee_level1'] as num).toDouble(),
      dunningFeeLevel2: (row['dunning_fee_level2'] as num).toDouble(),
      dunningFeeLevel3: (row['dunning_fee_level3'] as num).toDouble(),
      defaultHourlyRate: (row['default_hourly_rate'] as num).toDouble(),
    );
  }

  Tenant _fromRowNoSecrets(Map<String, dynamic> row) => Tenant(
        id: row['id'] as String,
        name: row['name'] as String,
        createdAt: (row['created_at'] as DateTime).toUtc(),
        brandingColor: row['branding_color'] as String?,
        companyAddress: row['company_address'] as String?,
        companyTaxId: row['company_tax_id'] as String?,
        companyIban: row['company_iban'] as String?,
        logoUrl: row['logo_url'] as String?,
        defaultVatRate: (row['default_vat_rate'] as num).toDouble(),
        reducedVatRate: (row['reduced_vat_rate'] as num).toDouble(),
        dunningFeeLevel1: (row['dunning_fee_level1'] as num).toDouble(),
        dunningFeeLevel2: (row['dunning_fee_level2'] as num).toDouble(),
        dunningFeeLevel3: (row['dunning_fee_level3'] as num).toDouble(),
        defaultHourlyRate: (row['default_hourly_rate'] as num).toDouble(),
      );
}
