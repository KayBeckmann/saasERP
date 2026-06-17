-- Migration 026: IBAN für den Mandanten (Briefkopf/Zahlungshinweis auf Rechnungen)
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS company_iban TEXT;
