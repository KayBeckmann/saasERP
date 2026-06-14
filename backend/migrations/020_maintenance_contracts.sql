-- M2b: Wartungsverträge/Abos zwischen Mandant und Endkunde — Datenmodell und
-- Verwaltung im User-App. Grundlage für die spätere Kundenportal-Ansicht
-- (Einsicht/Kündigung mit Vertragsstrafen-Vorschau gemäß M0-Formel
-- Strafe = maximale Strafe × Restlaufzeit/Laufzeit).
CREATE TABLE IF NOT EXISTS maintenance_contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    contract_number TEXT NOT NULL,
    title TEXT NOT NULL,
    term_months INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    notice_period_months INTEGER NOT NULL DEFAULT 1,
    max_penalty DOUBLE PRECISION NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'active',
    cancelled_at DATE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS maintenance_contracts_tenant_idx ON maintenance_contracts (tenant_id);
CREATE INDEX IF NOT EXISTS maintenance_contracts_customer_idx ON maintenance_contracts (customer_id);
