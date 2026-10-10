-- ERP tenant -> end-customer only; no platform subscription or bank account fields.
CREATE TABLE IF NOT EXISTS waas_psp_merchants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  provider TEXT NOT NULL CHECK (provider = 'fake'),
  credential_alias TEXT NOT NULL CHECK (length(credential_alias) BETWEEN 1 AND 128),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tenant_id), UNIQUE (provider, credential_alias), UNIQUE (id, tenant_id)
);
CREATE TABLE IF NOT EXISTS waas_psp_mandates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID NOT NULL,
  tenant_id UUID NOT NULL,
  customer_id UUID NOT NULL,
  provider_ref TEXT NOT NULL,
  hosted_url TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','active','revoked')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (merchant_id, tenant_id) REFERENCES waas_psp_merchants(id, tenant_id),
  UNIQUE (merchant_id, provider_ref), UNIQUE (id, merchant_id, tenant_id, customer_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS waas_psp_one_current_mandate ON waas_psp_mandates (tenant_id, customer_id) WHERE status != 'revoked';
CREATE TABLE IF NOT EXISTS waas_psp_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID NOT NULL,
  tenant_id UUID NOT NULL,
  customer_id UUID NOT NULL,
  mandate_id UUID NOT NULL,
  invoice_id UUID NOT NULL UNIQUE REFERENCES invoices(id) ON DELETE RESTRICT,
  provider_ref TEXT NOT NULL,
  amount_cents INTEGER NOT NULL CHECK (amount_cents > 0),
  status TEXT NOT NULL CHECK (status IN ('submitted','settled','failed','returned')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (mandate_id, merchant_id, tenant_id, customer_id) REFERENCES waas_psp_mandates(id, merchant_id, tenant_id, customer_id),
  UNIQUE (merchant_id, provider_ref)
);
CREATE TABLE IF NOT EXISTS waas_psp_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID NOT NULL REFERENCES waas_psp_merchants(id),
  provider_event_id TEXT NOT NULL,
  body_sha256 TEXT NOT NULL,
  event_type TEXT NOT NULL,
  outcome TEXT NOT NULL CHECK (outcome IN ('applied','ignored')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (merchant_id, provider_event_id)
);
