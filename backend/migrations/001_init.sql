-- M1: Multi-Tenant-Fundament — Tenants und Users
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'owner',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Self-Service-Registrierung: jede E-Mail-Adresse gehört genau einem Account
-- (Mehrfach-Mandanten pro Nutzer / Tenant-Auswahl ist spätere Erweiterung, siehe Roadmap M1)
CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique ON users (lower(email));
