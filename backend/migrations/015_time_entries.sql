-- M2: Beleg-Workflow — Stundenerfassung mit Wochenansicht. Jeder Nutzer
-- erfasst seine Arbeitszeit tageweise, optional einem Auftrag zugeordnet
-- (Basis für spätere Abrechnung der erfassten Stunden, z. B. als
-- Hours-Position einer Teil-/Schlussrechnung — folgt in einer späteren
-- Session).
CREATE TABLE IF NOT EXISTS time_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    work_date DATE NOT NULL,
    hours DOUBLE PRECISION NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS time_entries_tenant_idx ON time_entries (tenant_id);
CREATE INDEX IF NOT EXISTS time_entries_user_date_idx ON time_entries (user_id, work_date);
