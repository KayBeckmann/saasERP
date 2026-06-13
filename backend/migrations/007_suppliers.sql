-- M2: Lieferantenstamm (Freitext-first, analog customers). E-Mail/Telefon/
-- Adresse/IBAN/Notizen werden anwendungsseitig pro Mandant feldverschlüsselt
-- gespeichert (Envelope-Encryption, siehe TenantEncryptionService).
CREATE TABLE IF NOT EXISTS suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    contact_person TEXT,
    email TEXT,
    phone TEXT,
    address TEXT,
    iban TEXT,
    payment_terms_days INTEGER,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS suppliers_tenant_idx ON suppliers (tenant_id);
