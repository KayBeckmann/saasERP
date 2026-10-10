-- Additive subscription metadata; maintenance contracts and WaaS remain independent.
ALTER TABLE quotes ADD COLUMN IF NOT EXISTS is_subscription BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE quotes ADD COLUMN IF NOT EXISTS billing_interval TEXT;
ALTER TABLE quotes ADD COLUMN IF NOT EXISTS billing_start_date DATE;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS is_subscription BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS billing_interval TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS billing_start_date DATE;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'quotes_subscription_valid') THEN
    ALTER TABLE quotes ADD CONSTRAINT quotes_subscription_valid CHECK (NOT is_subscription OR (customer_id IS NOT NULL AND billing_start_date IS NOT NULL AND billing_interval IN ('weekly','monthly','quarterly','semiannual','yearly')));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'orders_subscription_valid') THEN
    ALTER TABLE orders ADD CONSTRAINT orders_subscription_valid CHECK (NOT is_subscription OR (customer_id IS NOT NULL AND billing_start_date IS NOT NULL AND billing_interval IN ('weekly','monthly','quarterly','semiannual','yearly')));
  END IF;
END $$;
CREATE TABLE IF NOT EXISTS order_subscription_invoice_runs (
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  period_start DATE NOT NULL,
  invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE RESTRICT,
  PRIMARY KEY (order_id, period_start),
  UNIQUE (invoice_id)
);
CREATE INDEX IF NOT EXISTS order_subscription_invoice_runs_tenant_idx ON order_subscription_invoice_runs (tenant_id);
