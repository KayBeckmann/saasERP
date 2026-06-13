-- M2: Produkte (neu) — Bundle aus Artikeln + Arbeitszeit mit eigenem
-- Verkaufspreis. `pending_sale_price` ist ein nach Preisimport berechneter
-- Vorschlag (proportionale Anpassung an Kostenänderung), der vom Owner
-- bestätigt oder verworfen werden muss (siehe Roadmap-Entscheidung
-- "Produkt-Preisaktualisierung: Vorschlag mit Bestätigung").
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    sku TEXT,
    name TEXT NOT NULL,
    sale_price DOUBLE PRECISION NOT NULL DEFAULT 0,
    pending_sale_price DOUBLE PRECISION,
    vat_rate DOUBLE PRECISION NOT NULL DEFAULT 19.0,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS products_tenant_idx ON products (tenant_id);

-- Positionen eines Produkts: entweder ein Artikel (mit Mengenangabe und
-- EK-Preis-Schnappschuss in unit_cost) oder eine Arbeitszeit-Position
-- (label = Bezeichnung, quantity = Stunden, unit_cost = Stundensatz).
CREATE TABLE IF NOT EXISTS product_components (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    kind TEXT NOT NULL,
    article_id UUID REFERENCES articles(id) ON DELETE SET NULL,
    label TEXT,
    quantity DOUBLE PRECISION NOT NULL DEFAULT 1,
    unit_cost DOUBLE PRECISION NOT NULL DEFAULT 0,
    sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS product_components_product_idx ON product_components (product_id);
CREATE INDEX IF NOT EXISTS product_components_article_idx ON product_components (article_id);
