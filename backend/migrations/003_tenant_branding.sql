-- M1: Theming/Branding pro Mandant — Grundlage für späteres Whitelabel
-- (generisches Theme bleibt Default, solange branding_color NULL ist).
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS branding_color TEXT;
