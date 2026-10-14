-- Dauerhafte Quellverweise für Bestellpositionen (Roadmap 2026-10-14,
-- "Unverzichtbarer Elektro-/Handwerksfluss: Raumgruppen → Auftrag →
-- Lieferantenbestellungen"): eine Bestellposition fasst für den Einkauf
-- dieselbe Artikel-SKU über mehrere Auftrags-Positionsgruppen hinweg
-- zusammen, muss aber für Nachkalkulation und Rückverfolgung wissen,
-- welche Auftragsposition(en)/Raumgruppe(n) mit welcher Menge beigetragen
-- haben. Deshalb eine Junction-Tabelle statt einer einzelnen FK-Spalte auf
-- purchase_order_items — eine Bestellposition kann mehrere Quellen haben.
--
-- order_id/group_label/quantity werden zum Anlagezeitpunkt eingefroren
-- (wie der WaaS-Rechnungs-Snapshot aus RF1): order_items wird bei jeder
-- Auftragsänderung komplett ersetzt (neue IDs), ON DELETE SET NULL auf
-- order_item_id verliert dadurch irgendwann die Live-Verknüpfung — die
-- eingefrorenen Felder bleiben trotzdem für Nachkalkulation/Anzeige
-- erhalten.
CREATE TABLE IF NOT EXISTS purchase_order_item_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    purchase_order_item_id UUID NOT NULL REFERENCES purchase_order_items(id) ON DELETE CASCADE,
    order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
    order_item_id UUID REFERENCES order_items(id) ON DELETE SET NULL,
    group_label TEXT,
    quantity DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS purchase_order_item_sources_po_item_idx
    ON purchase_order_item_sources (purchase_order_item_id);

-- Für die "bereits bestellt für diesen Auftrag"-Idempotenzprüfung beim
-- erneuten Abruf des Bestellvorschlags (verhindert Doppelbestellungen bei
-- wiederholtem Aufruf/Sync-Retry).
CREATE INDEX IF NOT EXISTS purchase_order_item_sources_order_idx
    ON purchase_order_item_sources (tenant_id, order_id);
