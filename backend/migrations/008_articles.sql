-- M2: Artikelstamm (Freitext-first). usage_count wird beim Verwenden in
-- Belegen hochgezählt und dient später als Sortierkriterium für
-- "häufig verwendet" in Positions-Pickern.
CREATE TABLE IF NOT EXISTS articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    sku TEXT,
    name TEXT NOT NULL,
    unit TEXT,
    purchase_price DOUBLE PRECISION,
    sale_price DOUBLE PRECISION,
    vat_rate DOUBLE PRECISION NOT NULL DEFAULT 19.0,
    usage_count INTEGER NOT NULL DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS articles_tenant_idx ON articles (tenant_id);
CREATE INDEX IF NOT EXISTS articles_tenant_usage_idx ON articles (tenant_id, usage_count DESC);
