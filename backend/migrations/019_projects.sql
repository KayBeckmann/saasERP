-- M2: Projektverwaltung — Projekt als Klammer für Aufträge, Bestellungen und
-- Stundenerfassung, plus sonstige Einnahmen/Ausgaben und Stundensatz als
-- Grundlage für die Gewinn/Verlust-Übersicht je Projekt.
CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    project_number TEXT NOT NULL,
    name TEXT NOT NULL,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'open',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS projects_tenant_idx ON projects (tenant_id);

ALTER TABLE orders ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES projects(id) ON DELETE SET NULL;
ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES projects(id) ON DELETE SET NULL;
ALTER TABLE time_entries ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES projects(id) ON DELETE SET NULL;

-- Stundensatz für die interne Verrechnung erfasster Stunden in der
-- Projekt-Gewinn/Verlust-Übersicht.
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS default_hourly_rate DOUBLE PRECISION NOT NULL DEFAULT 0;

-- Sonstige Einnahmen/Ausgaben eines Projekts ohne eigenen Beleg (z. B.
-- Zuschüsse, Spesen).
CREATE TABLE IF NOT EXISTS project_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    kind TEXT NOT NULL,
    description TEXT NOT NULL,
    amount DOUBLE PRECISION NOT NULL,
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS project_transactions_project_idx ON project_transactions (project_id);
