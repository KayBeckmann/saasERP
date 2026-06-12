-- M1: Verschlüsselung pro Mandant — Envelope-Encryption.
-- Jeder Mandant erhält einen eigenen Data Encryption Key (DEK), der mit dem
-- globalen Master-Key (ENCRYPTION_MASTER_KEY) verschlüsselt gespeichert wird.
CREATE TABLE IF NOT EXISTS tenant_encryption_keys (
    tenant_id UUID PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE,
    wrapped_key TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
