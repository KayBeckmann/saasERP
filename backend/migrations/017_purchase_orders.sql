-- M2: Bestellwesen — Bestellungen beim Großhandel, generiert aus Aufträgen
-- oder manuell angelegt. `purchase_order_number` wird über den
-- Nummernkreis "purchase_order" vergeben (Prefix "BE", z. B. "BE0001").
-- `status` durchläuft open -> ordered -> partially_delivered/fully_delivered.

-- Lagerbestand je Artikel (Basis für Bestellvorschlag: Fehlmenge = Bedarf
-- minus Bestand) und optionaler Standard-Lieferant (Basis für die
-- Gruppierung des Bestellvorschlags je Lieferant).
ALTER TABLE articles ADD COLUMN IF NOT EXISTS stock_quantity DOUBLE PRECISION NOT NULL DEFAULT 0;
ALTER TABLE articles ADD COLUMN IF NOT EXISTS default_supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS purchase_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    purchase_order_number TEXT NOT NULL,
    supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'open',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS purchase_orders_tenant_idx ON purchase_orders (tenant_id);

-- Positionen einer Bestellung: Artikel-Referenz optional (Freitext-Position
-- möglich), `quantity_delivered` trackt den bisherigen Wareneingang je
-- Position (Basis für den Status-Workflow und spätere Lagerbuchung).
CREATE TABLE IF NOT EXISTS purchase_order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    purchase_order_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
    article_id UUID REFERENCES articles(id) ON DELETE SET NULL,
    description TEXT NOT NULL,
    quantity DOUBLE PRECISION NOT NULL DEFAULT 1,
    quantity_delivered DOUBLE PRECISION NOT NULL DEFAULT 0,
    unit TEXT,
    unit_price DOUBLE PRECISION NOT NULL DEFAULT 0,
    sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS purchase_order_items_order_idx ON purchase_order_items (purchase_order_id);
