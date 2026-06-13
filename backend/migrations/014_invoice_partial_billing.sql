-- M2: Beleg-Workflow — Teil-/Abschlags-/Schlussrechnungen.
-- `invoice_items.order_item_id` referenziert die Auftragsposition, aus der
-- die Rechnungsposition übernommen wurde (Doppelabrechnungsschutz: eine
-- Auftragsposition darf nur einmal über alle nicht-stornierten Rechnungen
-- des Auftrags hinweg abgerechnet werden).
ALTER TABLE invoice_items ADD COLUMN IF NOT EXISTS order_item_id UUID REFERENCES order_items(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS invoice_items_order_item_idx ON invoice_items (order_item_id);

-- `invoice_type` unterscheidet Rechnung (standard) von Teilrechnung
-- (partial), Abschlagsrechnung (down_payment) und Schlussrechnung (final).
-- `prior_invoiced_total` (nur Schlussrechnung) summiert die Bruttobeträge
-- aller vorherigen, nicht-stornierten Rechnungen desselben Auftrags und
-- wird als Abzug ausgewiesen.
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS invoice_type TEXT NOT NULL DEFAULT 'standard';
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS prior_invoiced_total DOUBLE PRECISION;
