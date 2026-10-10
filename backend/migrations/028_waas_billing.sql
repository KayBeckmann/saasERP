-- Tenant -> end-customer recurring billing; distinct from platform subscriptions.
CREATE TABLE IF NOT EXISTS waas_plan_revisions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  contract_id UUID NOT NULL REFERENCES maintenance_contracts(id) ON DELETE RESTRICT,
  effective_from DATE NOT NULL,
  monthly_cents INTEGER NOT NULL CHECK (monthly_cents > 0),
  vat_basis_points INTEGER NOT NULL CHECK (vat_basis_points BETWEEN 0 AND 10000),
  description TEXT NOT NULL CHECK (length(trim(description)) > 0),
  created_by UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (contract_id, effective_from)
);
CREATE INDEX IF NOT EXISTS waas_plan_tenant_contract_idx ON waas_plan_revisions (tenant_id, contract_id, effective_from);

CREATE TABLE IF NOT EXISTS waas_billing_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  contract_id UUID NOT NULL REFERENCES maintenance_contracts(id) ON DELETE RESTRICT,
  plan_revision_id UUID NOT NULL REFERENCES waas_plan_revisions(id) ON DELETE RESTRICT,
  invoice_id UUID NOT NULL UNIQUE REFERENCES invoices(id) ON DELETE RESTRICT,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  approved_by UUID,
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (period_end > period_start),
  UNIQUE (tenant_id, contract_id, period_start)
);
