-- M2b: Endkunde kann ein versendetes Angebot im Kundenportal annehmen oder
-- ablehnen — Zeitstempel der Entscheidung + optionaler Kommentar.
ALTER TABLE quotes ADD COLUMN IF NOT EXISTS customer_decision_at TIMESTAMPTZ;
ALTER TABLE quotes ADD COLUMN IF NOT EXISTS customer_comment TEXT;
