-- M4: Zahlungsabwicklung (Datenmodell) — saasERP rechnet sein eigenes
-- Produkt bei seinen Mandanten ab ("Eat your own dog food").
--
-- Zahlungsweg je Abo (Überweisung/PayPal/SEPA-Lastschrift).
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS payment_method TEXT NOT NULL DEFAULT 'bank_transfer';

-- Plattform-Rechnungen: saasERP → Mandant, je Abrechnungsperiode. Eigener
-- Nummernkreis 'platform_invoice' (Prefix "PR") über den bestehenden
-- NumberSequenceRepository — wie alle anderen Belegnummern je Mandant
-- unabhängig durchnummeriert.
CREATE TABLE IF NOT EXISTS platform_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
    invoice_number TEXT NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    amount DOUBLE PRECISION NOT NULL DEFAULT 0,
    payment_method TEXT NOT NULL DEFAULT 'bank_transfer',
    status TEXT NOT NULL DEFAULT 'open',
    due_date DATE NOT NULL,
    paid_at DATE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS platform_invoices_tenant_idx ON platform_invoices (tenant_id);
