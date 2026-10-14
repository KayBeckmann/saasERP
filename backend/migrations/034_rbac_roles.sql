-- RF2: Mehrmandanten, gemeinsamer Zugang und feinste Rechte.
--
-- Ersetzt die bisherige binäre Rolle (user_tenant_access.role TEXT,
-- 'owner'/'employee') durch mandantenfähige, anpassbare Rollen mit
-- modul-/aktionsbezogenen Rechten. Additiv/idempotent (siehe db.dart: kein
-- Migrations-Tracking, jede Datei läuft bei jedem Start erneut).

CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    -- Eingebaute Vorlagen ("Admin", "Buchhaltung", ...) sind pro Mandant
    -- kopiert und dort frei anpassbar (siehe Roadmap RF2: "anpassbare
    -- Rollen"); is_builtin markiert nur den Ursprung, keine Sperre.
    is_builtin BOOLEAN NOT NULL DEFAULT FALSE,
    -- Governance: die Admin-Rolle eines Mandanten darf nicht gelöscht und
    -- ihr letzter Träger nicht entfernt werden (siehe RoleRepository).
    is_admin_role BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, name)
);
CREATE INDEX IF NOT EXISTS roles_tenant_idx ON roles (tenant_id);

CREATE TABLE IF NOT EXISTS role_permissions (
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    module TEXT NOT NULL,
    action TEXT NOT NULL,
    PRIMARY KEY (role_id, module, action)
);

-- user_tenant_access.role (TEXT, 'owner'/'employee') -> role_id (FK auf
-- roles). Kay hat die Datenbank für diese Umstellung bewusst frisch
-- aufgesetzt (siehe 10_Projects/saasERP/Roadmap.md) — daher hier direkt die
-- alte Spalte entfernt statt eine Datenmigration für Bestandszeilen zu
-- bauen. Für ein künftiges Upgrade einer befüllten Instanz müsste vor dem
-- DROP jede Zeile auf eine echte Rolle gemappt werden (z. B. 'owner' ->
-- Admin-Rolle des jeweiligen Mandanten, 'employee' -> 'Nur Lesen').
ALTER TABLE user_tenant_access ADD COLUMN IF NOT EXISTS role_id UUID REFERENCES roles(id);
ALTER TABLE user_tenant_access DROP COLUMN IF EXISTS role;
ALTER TABLE user_tenant_access ALTER COLUMN role_id SET NOT NULL;

-- Sofortige Wirksamkeit bei Rollenwechsel (Roadmap: "Rollenwechsel sofort
-- wirksam"): es gibt bewusst KEINEN Versions-/Cache-Mechanismus im JWT für
-- Rechte - jede Autorisierungsprüfung liest role_id/role_permissions live
-- aus der DB (siehe AuthorizationService), ein Rollenwechsel wirkt daher ab
-- der nächsten Anfrage ohne Re-Login.
