-- M2b: Kundenzugang (Mandant legt je Customer einen Kundenportal-Zugang an
-- und versendet einen Einladungslink). Passwortvergabe erfolgt durch den
-- Endkunden über den Einladungs-Token; danach ist der Zugang "active".
CREATE TABLE IF NOT EXISTS customer_portal_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    password_hash TEXT,
    invite_token TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'invited',
    invited_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    activated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (customer_id)
);

CREATE INDEX IF NOT EXISTS customer_portal_accounts_tenant_idx ON customer_portal_accounts (tenant_id);
