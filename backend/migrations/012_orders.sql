-- M2: Beleg-Workflow — Aufträge. `order_number` wird über den
-- Nummernkreis "order" (Prefix "AU", z. B. "AU0001") vergeben.
-- `status` durchläuft open -> in_progress -> completed/cancelled.
-- `quote_id` referenziert das Angebot, aus dem der Auftrag erzeugt wurde
-- (optional — Aufträge können auch direkt angelegt werden).
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    order_number TEXT NOT NULL,
    quote_id UUID REFERENCES quotes(id) ON DELETE SET NULL,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open',
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS orders_tenant_idx ON orders (tenant_id);

-- Positionen eines Auftrags: Freitext, Artikel-/Produkt-Referenz oder
-- Stunden-Position, inkl. Gruppen-Label für Zwischensummen (von Anfang an,
-- wie bei quote_items nach Migration 011). `unit_price`/`vat_rate` sind
-- Schnappschüsse zum Anlagezeitpunkt.
CREATE TABLE IF NOT EXISTS order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    kind TEXT NOT NULL DEFAULT 'text',
    article_id UUID REFERENCES articles(id) ON DELETE SET NULL,
    product_id UUID REFERENCES products(id) ON DELETE SET NULL,
    description TEXT NOT NULL,
    quantity DOUBLE PRECISION NOT NULL DEFAULT 1,
    unit TEXT,
    unit_price DOUBLE PRECISION NOT NULL DEFAULT 0,
    vat_rate DOUBLE PRECISION NOT NULL DEFAULT 19.0,
    group_label TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS order_items_order_idx ON order_items (order_id);
