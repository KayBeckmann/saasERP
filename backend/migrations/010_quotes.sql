-- M2: Beleg-Workflow — Angebote. `quote_number` wird über den
-- Nummernkreis "quote" (Prefix "A", z. B. "A0001") vergeben.
-- `status` durchläuft draft -> sent -> accepted/rejected.
CREATE TABLE IF NOT EXISTS quotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    quote_number TEXT NOT NULL,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft',
    valid_until DATE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS quotes_tenant_idx ON quotes (tenant_id);

-- Positionen eines Angebots: Freitext, Artikel-/Produkt-Referenz oder
-- Stunden-Position. `unit_price`/`vat_rate` sind Schnappschüsse zum
-- Anlagezeitpunkt (Preisänderungen am Artikel/Produkt wirken nicht
-- nachträglich auf bestehende Angebote).
CREATE TABLE IF NOT EXISTS quote_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    quote_id UUID NOT NULL REFERENCES quotes(id) ON DELETE CASCADE,
    kind TEXT NOT NULL DEFAULT 'text',
    article_id UUID REFERENCES articles(id) ON DELETE SET NULL,
    product_id UUID REFERENCES products(id) ON DELETE SET NULL,
    description TEXT NOT NULL,
    quantity DOUBLE PRECISION NOT NULL DEFAULT 1,
    unit TEXT,
    unit_price DOUBLE PRECISION NOT NULL DEFAULT 0,
    vat_rate DOUBLE PRECISION NOT NULL DEFAULT 19.0,
    sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS quote_items_quote_idx ON quote_items (quote_id);
