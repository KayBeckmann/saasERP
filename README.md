# saasERP

Mandantenfähiges ERP-System für Handwerksbetriebe — Flutter (Web/Android/Linux/Windows) + Dart Frog Backend + PostgreSQL.

## Funktionsumfang

- **Belegfluss:** Angebote → Aufträge → Rechnungen (Teil-/Abschlags-/Schluss), PDF & ZUGFeRD/XRechnung
- **Stammdaten:** Kunden, Lieferanten, Artikel (inkl. Preisimport), Produkte/Bundles
- **Bestellwesen:** Bestellvorschlag aus Auftrag, Wareneingang, Lagerbestand
- **Projektverwaltung:** Einnahmen/Ausgaben/Stunden je Projekt, Gewinn/Verlust-Übersicht
- **Mahnwesen:** Mahnstufen, Mahngebühren, PDF-Mahnungen
- **Kundenportal:** Angebote freigeben, Rechnungen einsehen, Wartungsverträge kündigen
- **Mehrbenutzer:** Owner + Mitarbeiter je Mandant, Mandanten-Whitelabel-Branding
- **SaaS-Basis:** Abo-Verwaltung, Plattform-Rechnungen, Monitoring, Backup

## Dokumentation

- [Funktionsübersicht](docs/FEATURES.md)
- [Benutzerhandbuch](docs/BENUTZERHANDBUCH.md)
- [Self-Hosting-Anleitung](docs/SELF-HOSTING.md)
- [Lizenzmodell](docs/LIZENZMODELL.md)
- [AGB (Entwurf)](docs/AGB.md)
- [Datenschutzerklärung (Entwurf)](docs/DATENSCHUTZERKLAERUNG.md)
- [Auftragsverarbeitungsvertrag (Entwurf)](docs/AVV.md)
- [Impressum (Entwurf)](docs/IMPRESSUM.md)

## Stack

| Schicht | Technologie |
|---------|-------------|
| Backend | Dart Frog (Dart) |
| Datenbank | PostgreSQL 16 |
| User-App | Flutter Web/Android/Linux/Windows |
| Kunden-App | Flutter Web |
| Gemeinsame Modelle | Dart Package (`shared/`) |
| Betrieb | Docker Compose |

## Quickstart (Self-Hosting)

```bash
cp .env.example .env
# .env anpassen (DB-Passwörter, ENCRYPTION_MASTER_KEY, JWT_SECRET)
docker-compose up -d
```

User-App: http://localhost:8081  
Kunden-App: http://localhost:8082  
Backend-API: http://localhost:8091

Vollständige Anleitung: [docs/SELF-HOSTING.md](docs/SELF-HOSTING.md)

## Lizenz

MIT — siehe [LICENSE](LICENSE)
