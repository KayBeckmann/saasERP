-- M2: Beleg-Workflow — Angebote-Gruppen. Positionen können über ein
-- gemeinsames `group_label` zu Gruppen mit Zwischensumme zusammengefasst
-- werden. Eine eigene Gruppentabelle ist nicht nötig: Gruppenreihenfolge
-- ergibt sich aus dem ersten Auftreten des Labels in `sort_order`.
ALTER TABLE quote_items ADD COLUMN IF NOT EXISTS group_label TEXT;
