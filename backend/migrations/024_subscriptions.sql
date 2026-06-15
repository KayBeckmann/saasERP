-- M3: Abo-Datenmodell — saasERP verwaltet seine eigenen Mandantenverträge.
--
-- Plattform-Administration: ein neues, globales (nicht mandanten-gescoptes)
-- Flag auf users. Der chronologisch erste je registrierte Nutzer wird einmalig
-- zum Plattform-Admin gemacht (Bootstrap), aber nur falls noch keiner
-- existiert — spätere manuelle Änderungen werden bei erneutem Migrationslauf
-- nicht überschrieben.
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_platform_admin BOOLEAN NOT NULL DEFAULT false;

UPDATE users SET is_platform_admin = true
WHERE id = (SELECT id FROM users ORDER BY created_at ASC, id ASC LIMIT 1)
  AND NOT EXISTS (SELECT 1 FROM users WHERE is_platform_admin = true);

-- Abo-Tiers: global gepflegt vom Plattform-Admin, nicht mandanten-gescopt.
CREATE TABLE IF NOT EXISTS subscription_tiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    monthly_price DOUBLE PRECISION NOT NULL DEFAULT 0,
    yearly_price DOUBLE PRECISION NOT NULL DEFAULT 0,
    user_limit INTEGER,
    feature_summary TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS subscription_tiers_name_unique ON subscription_tiers (lower(name));

INSERT INTO subscription_tiers (name, monthly_price, yearly_price, user_limit, feature_summary, sort_order)
VALUES
    ('Starter', 19, 199, 2, 'Basis-ERP-Funktionen, bis 2 Benutzer', 1),
    ('Professional', 49, 499, 10, 'Inkl. Kundenportal, Projektverwaltung, bis 10 Benutzer', 2),
    ('Enterprise', 99, 999, NULL, 'Alle Funktionen, unbegrenzte Benutzer, Priority-Support', 3)
ON CONFLICT (lower(name)) DO NOTHING;

-- Abo eines Mandanten bei saasERP. 1:n je Mandant (Historie bei Tier-Wechsel/
-- Kündigung/Neuabschluss) — das jeweils aktuelle Abo ist das mit
-- status = 'active'.
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    tier_id UUID REFERENCES subscription_tiers(id) ON DELETE SET NULL,
    payment_rhythm TEXT NOT NULL DEFAULT 'monthly',
    term_months INTEGER NOT NULL DEFAULT 12,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    down_payment DOUBLE PRECISION NOT NULL DEFAULT 0,
    max_penalty DOUBLE PRECISION NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'active',
    cancelled_at DATE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS subscriptions_tenant_idx ON subscriptions (tenant_id);
