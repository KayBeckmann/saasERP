# Lokale PDF-Layout-Vorschau (synthetische Beispieldaten)

Belege: `angebot.pdf`, `rechnung-waas.pdf`, `rechnung-mehrseitig.pdf` (3 Seiten), `bestellung.pdf`, `mahnung.pdf`.

Neu erzeugen, vom Repo-Verzeichnis aus:

```sh
cd backend
PDF_PREVIEW_DIR=../artifacts/pdf-layout-preview dart test test/pdf_layout_test.dart
```

Ohne Backend, DB oder Netzwerk zur Laufzeit erzeugt. Zum visuellen Prüfen: `pdftoppm -f 1 -l 1 -png -scale-to 1100 rechnung-waas.pdf rechnung-waas-page1`; Inhalt mit `pdftotext -layout rechnung-waas.pdf -` und Format/Seiten mit `pdfinfo rechnung-waas.pdf` prüfen. Die PNGs sind gerenderte QA-Ansichten, nicht Produktionsdokumente. Vorhandene ausgestellte Belege bleiben unverändert.
