import 'package:postgres/postgres.dart';
import 'package:saaserp_shared/saaserp_shared.dart';

class TenantRepository {
  TenantRepository(this._pool);

  final Pool<void> _pool;

  static const _columns = 'id, name, created_at, branding_color, '
      'company_address, company_tax_id, logo_url, '
      'default_vat_rate, reduced_vat_rate, '
      'dunning_fee_level1, dunning_fee_level2, dunning_fee_level3, '
      'default_hourly_rate';

  Future<Tenant> create(String name) async {
    final result = await _pool.execute(
      Sql.named('INSERT INTO tenants (name) VALUES (@name) RETURNING $_columns'),
      parameters: {'name': name},
    );
    return _fromRow(result.first.toColumnMap());
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
    final result = await _pool.execute(
      Sql.named(
        'UPDATE tenants SET '
        'company_address = @company_address, '
        'company_tax_id = @company_tax_id, '
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
        'company_address': config.companyAddress,
        'company_tax_id': config.companyTaxId,
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

  Tenant _fromRow(Map<String, dynamic> row) => Tenant(
        id: row['id'] as String,
        name: row['name'] as String,
        createdAt: (row['created_at'] as DateTime).toUtc(),
        brandingColor: row['branding_color'] as String?,
        companyAddress: row['company_address'] as String?,
        companyTaxId: row['company_tax_id'] as String?,
        logoUrl: row['logo_url'] as String?,
        defaultVatRate: (row['default_vat_rate'] as num).toDouble(),
        reducedVatRate: (row['reduced_vat_rate'] as num).toDouble(),
        dunningFeeLevel1: (row['dunning_fee_level1'] as num).toDouble(),
        dunningFeeLevel2: (row['dunning_fee_level2'] as num).toDouble(),
        dunningFeeLevel3: (row['dunning_fee_level3'] as num).toDouble(),
        defaultHourlyRate: (row['default_hourly_rate'] as num).toDouble(),
      );
}
