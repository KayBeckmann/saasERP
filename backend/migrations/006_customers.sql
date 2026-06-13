-- M2: Kundenstamm (Freitext-first). E-Mail/Telefon/Adresse/Notizen werden
-- anwendungsseitig pro Mandant feldverschlüsselt gespeichert (Envelope-
-- Encryption, siehe TenantEncryptionService) — daher hier TEXT statt z.B.
-- strukturierter Adressfelder.
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_number TEXT NOT NULL,
    kind TEXT NOT NULL DEFAULT 'private',
    name TEXT NOT NULL,
    contact_person TEXT,
    email TEXT,
    phone TEXT,
    address TEXT,
    e_invoice_format TEXT NOT NULL DEFAULT 'none',
    leitweg_id TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS customers_tenant_number_unique
    ON customers (tenant_id, customer_number);
CREATE INDEX IF NOT EXISTS customers_tenant_idx ON customers (tenant_id);
