# saasERP — Funktionsübersicht

saasERP ist ein mandantenfähiges ERP-System für **Handwerksbetriebe** — von Elektrikern über Heizungsbauer bis zu Schreinern. Es deckt den kompletten kaufmännischen Ablauf ab: von der Anfrage über Angebote, Aufträge, Rechnungen bis zum Mahnwesen — und geht mit Projektverwaltung, Kundenportal und Wartungsvertragsmanagement deutlich über ein reines Faktura-System hinaus.

---

## Kernfunktionen

### Angebote, Aufträge, Rechnungen

- **Durchgängiger Belegfluss:** Angebot → Auftrag → Rechnung mit einem Klick konvertieren
- **Positionsarten:** Freitext, Artikel, Produkte (Bundles aus Material + Arbeit), Stundeneinträge
- **Positionsgruppen** mit automatischen Zwischensummen (z. B. "Elektroinstallation", "Sanitär")
- **PDF-Export** direkt aus der App (Briefkopf mit Firmendaten, Logo, USt-IdNr.)
- **E-Rechnung** (ZUGFeRD 2.1 / XRechnung) für B2B- und B2G-Kunden — gesetzeskonform ab 2025
- **Teil-/Abschlags-/Schlussrechnungen** mit automatischem Doppelabrechnungsschutz
- **Mahnwesen** mit drei Mahnstufen, konfigurierbaren Mahngebühren und Mahnungs-PDF

### Stammdaten

- **Kundenstamm** mit automatischer Kundennummernvergabe, Feldverschlüsselung für PII, B2G-Leitweg-ID für E-Rechnungen
- **Lieferantenstamm** mit Ansprechpartner, IBAN und Zahlungsziel
- **Artikelstamm** mit SKU, Einheit, EK-/VK-Preis und Lagerbestand
- **Preisimport** aus Großhändler-Preislisten (CSV via SKU-Matching), mit Preisvorschlags-Workflow für betroffene Produkte
- **Produkte** als Bundles aus Artikeln und Arbeitszeit — Kostensumme wird live berechnet

### Bestellwesen & Lager

- **Bestellungen beim Großhandel** anlegen, Bestellvorschlag automatisch aus Auftragsbedarf berechnen
- **Lagerbestand** wird automatisch beim Wareneingang erhöht und beim Auftragsabschluss verbraucht
- **Mindestbestand-Hinweis** in der Bestandsübersicht hebt kritische Artikel farblich hervor

### Projektverwaltung

- **Projekte** als optionale Klammer für Aufträge, Bestellungen und Stundenerfassungen
- **Gewinn/Verlust-Übersicht** je Projekt: Rechnungseinnahmen + sonstige Einnahmen − Materialkosten − interne Stundenkosten (zum konfigurierbaren Stundensatz)

### Stundenerfassung

- **Wochenansicht** mit Tages- und Wochensumme
- Zeiteinträge optional einem Auftrag zuordnen

### Auswertungen & Export

- **Dashboard** mit offenen Belegen, überfälligen Rechnungen (Anzahl + Summe) und Monatsstunden
- **Steuerberater-Export** als CSV (Semikolon-getrennt, deutsches Dezimalkomma) für alle Rechnungen eines Zeitraums

---

## Kundenportal

Endkunden erhalten eine **eigene App** (Kundenportal / Kunden-App) — getrennt vom Mandanten-Interface:

- **Einladungslink** je Kunde: der Betrieb lädt Kunden per Link ein, der Kunde vergibt ein eigenes Passwort
- **Angebote** online einsehen, freigeben oder ablehnen (mit optionalem Kommentar)
- **Rechnungen** einsehen inkl. Zahlungsstatus und PDF-Download
- **Wartungsverträge** einsehen — Laufzeit, Kündigungsfrist und Vertragsstrafen-Vorschau bei vorzeitiger Kündigung
- **Dokumente** hochladen (Fotos, Pläne, Vollmachten) — direkt aus dem Kundenportal
- **Whitelabel-Branding** pro Mandant: Logo und Primärfarbe des Betriebs erscheinen im Kundenportal

---

## SaaS-Verwaltung (Plattform-Admin)

Für den Betrieb von saasERP als eigenes SaaS-Produkt:

- **Abo-Verwaltung** (Tiers: Starter / Professional / Enterprise mit Monats-/Jahrespreisen, Nutzerlimits, Anzahlung)
- **Plattform-Rechnungen** an Mandanten (automatische Rechnungsnummern PR0001 ff., manueller Zahlungseingang, überfällige Rechnungen global im Überblick)
- **Mandanten-Übersicht** und Abo-Eingriff durch den Plattform-Admin
- **Plattform-Metriken** (Mandantenanzahl, aktive Abos, offene/überfällige Rechnungen)

---

## Sicherheit & Datenschutz

- **Mandantenisolierung:** Daten sind strikt pro Mandant getrennt — kein Mandant sieht Daten eines anderen
- **Envelope-Encryption:** Sensible Felder (E-Mail, Telefon, Adresse) werden mit AES-256-CBC pro Mandant verschlüsselt
- **JWT-Auth** (HS256, 12h Gültigkeit) für Mandanten-Nutzer und Kunden-Portal-Nutzer
- **Rollenmodell:** `owner` und `employee` je Mandant; plattformweiter `is_platform_admin`-Flag

---

## Technischer Stack

| Komponente | Technologie |
|---|---|
| Backend | Dart Frog (Dart) |
| Datenbank | PostgreSQL 16 |
| User-App | Flutter (Web, Android, Linux, Windows) |
| Kunden-App | Flutter (Web) |
| Containerisierung | Docker / docker-compose |
| Deployment | Self-Hosting oder Managed SaaS |

---

## Lizenz

saasERP ist unter der **MIT-Lizenz** veröffentlicht — kostenlose Nutzung, Anpassung und Weitergabe unter Nennung des Urhebers.
