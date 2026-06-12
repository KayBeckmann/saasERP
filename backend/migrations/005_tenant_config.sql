-- M2: Mandanten-Konfiguration — Firmendaten, Logo, Steuersätze, Nummernkreise.
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS company_address TEXT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS company_tax_id TEXT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS logo_url TEXT;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS default_vat_rate DOUBLE PRECISION NOT NULL DEFAULT 19.0;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS reduced_vat_rate DOUBLE PRECISION NOT NULL DEFAULT 7.0;

-- Nummernkreise je Mandant (z. B. Kundennummern "K0001", später Belegnummern).
CREATE TABLE IF NOT EXISTS number_sequences (
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    sequence_key TEXT NOT NULL,
    prefix TEXT NOT NULL DEFAULT '',
    pad_width INTEGER NOT NULL DEFAULT 4,
    next_number INTEGER NOT NULL DEFAULT 1,
    PRIMARY KEY (tenant_id, sequence_key)
);
