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
-- Nur solange user_tenant_access.role (TEXT) noch existiert — Migration 034
-- (RF2) ersetzt sie durch role_id und entfernt die Spalte; dieser Block wird
-- danach übersprungen statt bei jedem Neustart erneut gegen die dann fehlende
-- Spalte zu laufen (kein Migrations-Tracking, siehe db.dart).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_tenant_access' AND column_name = 'role'
  ) THEN
    INSERT INTO user_tenant_access (user_id, tenant_id, role)
    SELECT id, tenant_id, role FROM users
    ON CONFLICT (user_id, tenant_id) DO NOTHING;
  END IF;
END $$;
