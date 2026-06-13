-- M2: Mahnwesen — Mahnstufen mit Mahngebühren je Mandant, Mahnstatus je
-- Rechnung.
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS dunning_level INTEGER NOT NULL DEFAULT 0;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS dunning_fee_total DOUBLE PRECISION NOT NULL DEFAULT 0;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS last_dunned_at TIMESTAMPTZ;

-- Mahngebühren je Stufe (Zahlungserinnerung gebührenfrei, 1./2. Mahnung mit
-- Gebühr) — konfigurierbar je Mandant, da die zulässige Höhe variieren kann.
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS dunning_fee_level1 DOUBLE PRECISION NOT NULL DEFAULT 0;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS dunning_fee_level2 DOUBLE PRECISION NOT NULL DEFAULT 5.0;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS dunning_fee_level3 DOUBLE PRECISION NOT NULL DEFAULT 10.0;
