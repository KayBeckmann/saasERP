-- M2b-Erweiterung: Dokumenten-Upload durch den Kunden (Fotos, Pläne,
-- Vollmachten) — mandantenfähige Dokumentenablage je Kunde. Dateien werden
-- als BYTEA in Postgres abgelegt (kein externer Objektspeicher).
CREATE TABLE IF NOT EXISTS documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    filename TEXT NOT NULL,
    content_type TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    content BYTEA NOT NULL,
    description TEXT,
    uploaded_by TEXT NOT NULL DEFAULT 'customer',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS documents_tenant_idx ON documents (tenant_id);
CREATE INDEX IF NOT EXISTS documents_customer_idx ON documents (customer_id);
