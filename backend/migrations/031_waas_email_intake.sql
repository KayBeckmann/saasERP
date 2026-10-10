-- Owner-authenticated manual import only. No sender-derived identity, invoices or publication.
CREATE UNIQUE INDEX IF NOT EXISTS customers_tenant_id_unique ON customers(tenant_id, id);
CREATE TABLE IF NOT EXISTS waas_intake (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  mailbox TEXT NOT NULL CHECK (length(mailbox) BETWEEN 1 AND 128),
  message_key TEXT NOT NULL CHECK (length(message_key) BETWEEN 1 AND 256),
  raw_sha256 TEXT NOT NULL,
  raw_message BYTEA NOT NULL,
  claimed_from TEXT NOT NULL DEFAULT '',
  claimed_subject TEXT NOT NULL DEFAULT '',
  instruction TEXT NOT NULL DEFAULT '',
  pdf_name TEXT,
  pdf_bytes BYTEA,
  customer_id UUID,
  verification_note TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','associated','reviewed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, mailbox, message_key),
  UNIQUE (id, tenant_id),
  FOREIGN KEY (tenant_id, customer_id) REFERENCES customers(tenant_id, id)
);
CREATE INDEX IF NOT EXISTS waas_intake_tenant_created ON waas_intake(tenant_id, created_at DESC);
CREATE TABLE IF NOT EXISTS waas_intake_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  request_id UUID NOT NULL,
  actor_id UUID NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('imported','associated','reviewed')),
  note TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  FOREIGN KEY (request_id, tenant_id) REFERENCES waas_intake(id, tenant_id) ON DELETE RESTRICT
);
