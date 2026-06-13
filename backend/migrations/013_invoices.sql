-- M2: Beleg-Workflow — Rechnungen. `invoice_number` wird über den
-- Nummernkreis "invoice" (Prefix "R", z. B. "R0001") vergeben.
-- `status` durchläuft draft -> sent -> paid/overdue/cancelled.
-- `order_id` referenziert den Auftrag, aus dem die Rechnung erzeugt wurde
-- (optional — Rechnungen können auch direkt angelegt werden).
CREATE TABLE IF NOT EXISTS invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    invoice_number TEXT NOT NULL,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft',
    due_date DATE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS invoices_tenant_idx ON invoices (tenant_id);

-- Positionen einer Rechnung: Freitext, Artikel-/Produkt-Referenz oder
-- Stunden-Position, inkl. Gruppen-Label für Zwischensummen (von Anfang an,
-- wie bei order_items). `unit_price`/`vat_rate` sind Schnappschüsse zum
-- Anlagezeitpunkt.
CREATE TABLE IF NOT EXISTS invoice_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
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

CREATE INDEX IF NOT EXISTS invoice_items_invoice_idx ON invoice_items (invoice_id);
