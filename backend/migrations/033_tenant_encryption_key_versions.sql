-- RF1: Versionierte Tenant-Schlüssel (DEK-Rotation).
--
-- Bisher genau ein wrapped_key pro Mandant (tenant_id PRIMARY KEY). Für
-- Schlüsselrotation müssen mehrere Versionen koexistieren können: die neue
-- (aktive) Version für künftige Verschlüsselungen, ältere (retired)
-- Versionen, bis alle damit verschlüsselten Bestandsdaten umgeschlüsselt
-- sind. Rein additiv (ALTER, keine DROP/CREATE) — idempotent und sicher bei
-- jedem Neustart erneut ausführbar (siehe db.dart: kein Migrations-Tracking,
-- jede Datei läuft bei jedem Start erneut).
ALTER TABLE tenant_encryption_keys ADD COLUMN IF NOT EXISTS key_version INT NOT NULL DEFAULT 1;
ALTER TABLE tenant_encryption_keys ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';
ALTER TABLE tenant_encryption_keys ADD COLUMN IF NOT EXISTS retired_at TIMESTAMPTZ;

ALTER TABLE tenant_encryption_keys DROP CONSTRAINT IF EXISTS tenant_encryption_keys_status_check;
ALTER TABLE tenant_encryption_keys ADD CONSTRAINT tenant_encryption_keys_status_check
  CHECK (status IN ('active', 'retired'));

-- Primärschlüssel von (tenant_id) auf (tenant_id, key_version) erweitern,
-- damit mehrere Versionen je Mandant koexistieren können. Nur einmalig
-- nötig — danach ist key_version bereits Teil des PK und der Block wird
-- übersprungen.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.key_column_usage
    WHERE table_name = 'tenant_encryption_keys'
      AND constraint_name = 'tenant_encryption_keys_pkey'
      AND column_name = 'key_version'
  ) THEN
    ALTER TABLE tenant_encryption_keys DROP CONSTRAINT tenant_encryption_keys_pkey;
    ALTER TABLE tenant_encryption_keys ADD PRIMARY KEY (tenant_id, key_version);
  END IF;
END $$;

-- Genau eine aktive Version je Mandant zu jedem Zeitpunkt.
CREATE UNIQUE INDEX IF NOT EXISTS tenant_encryption_keys_one_active
  ON tenant_encryption_keys (tenant_id) WHERE status = 'active';
