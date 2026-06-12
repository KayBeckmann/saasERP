-- M1: Mandanten-/Tenant-Auswahl — Nutzer können Zugriff auf mehrere
-- Mandanten haben (z. B. Berater mit Zugängen zu mehreren Firmen).
CREATE TABLE IF NOT EXISTS user_tenant_access (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, tenant_id)
);

-- Bestehende Nutzer erhalten Zugriff auf ihren bisherigen (einzigen) Mandanten.
INSERT INTO user_tenant_access (user_id, tenant_id, role)
SELECT id, tenant_id, role FROM users
ON CONFLICT (user_id, tenant_id) DO NOTHING;
