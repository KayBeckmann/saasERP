-- One persisted document pair per approved recurring invoice. A correction must
-- be a separately numbered invoice; never revise or delete an issued pair.
CREATE TABLE IF NOT EXISTS waas_invoice_documents (
  invoice_id UUID PRIMARY KEY REFERENCES invoices(id) ON DELETE RESTRICT,
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
  version INTEGER NOT NULL DEFAULT 1 CHECK (version = 1),
  snapshot JSONB NOT NULL,
  pdf BYTEA NOT NULL,
  xml BYTEA NOT NULL,
  approved_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (octet_length(pdf) > 0 AND octet_length(xml) > 0)
);
CREATE INDEX IF NOT EXISTS waas_document_customer_idx ON waas_invoice_documents (tenant_id, customer_id);

CREATE OR REPLACE FUNCTION reject_waas_document_mutation() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'Issued WaaS documents are immutable';
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS immutable_waas_document ON waas_invoice_documents;
CREATE TRIGGER immutable_waas_document BEFORE UPDATE OR DELETE ON waas_invoice_documents
FOR EACH ROW EXECUTE FUNCTION reject_waas_document_mutation();

-- The approval snapshot cannot be invalidated by edits through direct SQL or
-- generic invoice/item repositories. Status/payment state remains operational.
CREATE OR REPLACE FUNCTION guard_waas_invoice_item() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF EXISTS (SELECT 1 FROM waas_billing_runs WHERE invoice_id = NEW.invoice_id) THEN
      RAISE EXCEPTION 'WaaS invoice items cannot be changed; issue a correction invoice';
    END IF;
    RETURN NEW;
  END IF;
  IF EXISTS (SELECT 1 FROM waas_billing_runs WHERE invoice_id = OLD.invoice_id)
     OR (TG_OP = 'UPDATE' AND EXISTS (SELECT 1 FROM waas_billing_runs WHERE invoice_id = NEW.invoice_id)) THEN
    RAISE EXCEPTION 'WaaS invoice items cannot be changed; issue a correction invoice';
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS immutable_waas_item ON invoice_items;
CREATE TRIGGER immutable_waas_item BEFORE UPDATE OR DELETE ON invoice_items
FOR EACH ROW EXECUTE FUNCTION guard_waas_invoice_item();
DROP TRIGGER IF EXISTS immutable_waas_item_insert ON invoice_items;
CREATE TRIGGER immutable_waas_item_insert BEFORE INSERT ON invoice_items
FOR EACH ROW EXECUTE FUNCTION guard_waas_invoice_item();

CREATE OR REPLACE FUNCTION guard_waas_invoice_header() RETURNS trigger AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM waas_billing_runs WHERE invoice_id = OLD.id) AND
     (OLD.tenant_id, OLD.invoice_number, OLD.customer_id, OLD.title,
      OLD.notes, OLD.invoice_type, OLD.prior_invoiced_total, OLD.order_id)
     IS DISTINCT FROM
     (NEW.tenant_id, NEW.invoice_number, NEW.customer_id, NEW.title,
      NEW.notes, NEW.invoice_type, NEW.prior_invoiced_total, NEW.order_id) THEN
    RAISE EXCEPTION 'WaaS invoice details cannot be changed; issue a correction invoice';
  END IF;
  IF (OLD.due_date IS DISTINCT FROM NEW.due_date OR
      OLD.created_at IS DISTINCT FROM NEW.created_at) AND
     EXISTS (SELECT 1 FROM waas_billing_runs WHERE invoice_id = OLD.id
             AND approved_at IS NOT NULL) THEN
    RAISE EXCEPTION 'Issued WaaS dates cannot be changed';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS immutable_waas_invoice_header ON invoices;
CREATE TRIGGER immutable_waas_invoice_header BEFORE UPDATE ON invoices
FOR EACH ROW EXECUTE FUNCTION guard_waas_invoice_header();
