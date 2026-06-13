-- M2: Lagerverwaltung — Mindestbestand je Artikel als Basis für die
-- Bestandsübersicht (Hinweis, wenn stock_quantity unter minimum_stock fällt).
ALTER TABLE articles ADD COLUMN IF NOT EXISTS minimum_stock DOUBLE PRECISION NOT NULL DEFAULT 0;
