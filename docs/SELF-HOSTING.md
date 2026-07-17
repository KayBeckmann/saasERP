# saasERP — Self-Hosting-Anleitung

saasERP lässt sich vollständig selbst betreiben (On-Premises oder auf einem eigenen VPS). Docker und docker-compose werden benötigt — weitere Abhängigkeiten gibt es nicht.

---

## Voraussetzungen

| Software | Mindestversion |
|---|---|
| Docker | 20.10 |
| docker-compose | 1.29 |
| RAM | 512 MB (Empfehlung: 1 GB+) |
| Festplatte | 2 GB (zuzüglich Daten und Backups) |

---

## Installation

### 1. Repository klonen

```bash
git clone https://codeberg.org/KayBeckmann/saasERP.git
cd saasERP
```

### 2. Konfiguration

```bash
cp .env.example .env
```

Öffne `.env` und passe die Werte an:

```env
# PostgreSQL
POSTGRES_PASSWORD=<sicheres_passwort>

# Backend
JWT_SECRET=<mindestens_64_zufaellige_zeichen>
ENCRYPTION_MASTER_KEY=<mindestens_64_zufaellige_zeichen>

# URLs (auf deinen Domainnamen anpassen)
CORS_ORIGIN=https://app.meinedomain.de
APP_KUNDE_URL=https://portal.meinedomain.de
API_BASE_URL=https://api.meinedomain.de
```

> **Sicherheitshinweis:** `JWT_SECRET` und `ENCRYPTION_MASTER_KEY` sollten mindestens 64 zufällige Zeichen lang sein. Generieren mit:
> ```bash
> openssl rand -hex 32
> ```

### 3. Stack starten

```bash
docker-compose up -d
```

Beim ersten Start werden alle Datenbankmigrationen automatisch angewendet. Nach wenigen Sekunden sind die Dienste erreichbar:

| Dienst | Standardport |
|---|---|
| Backend (API) | 8080 |
| User-App (Mandanten-Interface) | 8081 |
| Kunden-App (Kundenportal) | 8082 |
| PostgreSQL | 5432 |

### 4. Erster Login

1. Öffne die User-App (`http://localhost:8081` oder deine Domain)
2. Klicke auf **Registrieren** und lege den ersten Mandanten an
3. Der erste registrierte Account erhält automatisch Plattform-Admin-Rechte

---

## Dienste hinter einem Reverse-Proxy betreiben (empfohlen)

Für den Produktionsbetrieb empfiehlt sich nginx oder Caddy als Reverse-Proxy mit TLS-Terminierung.

### Beispiel nginx-Konfiguration

```nginx
# User-App
server {
    listen 443 ssl;
    server_name app.meinedomain.de;

    ssl_certificate /etc/letsencrypt/live/meinedomain.de/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/meinedomain.de/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8081;
    }
}

# Kunden-App (Kundenportal)
server {
    listen 443 ssl;
    server_name portal.meinedomain.de;

    location / {
        proxy_pass http://127.0.0.1:8082;
    }
}

# Backend-API
server {
    listen 443 ssl;
    server_name api.meinedomain.de;

    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
```

Passe anschließend in `.env` die URLs entsprechend an:

```env
CORS_ORIGIN=https://app.meinedomain.de
APP_KUNDE_URL=https://portal.meinedomain.de
API_BASE_URL=https://api.meinedomain.de
```

### Alternative: nur zwei Domains, ohne eigene API-Subdomain

Falls keine dritte Subdomain für die API angelegt werden soll (z. B. wenn nur
`app.meinedomain.de` und `portal.meinedomain.de` existieren), proxied
`app_user/nginx.conf` bzw. `app_kunde/nginx.conf` `/api/` bereits intern zum
Backend-Container weiter. In diesem Fall reicht ein Reverse-Proxy-Eintrag pro
App-Domain (Ziel: der Host-Port der jeweiligen App, siehe `APP_USER_PORT`/
`APP_KUNDE_PORT`), eine eigene API-Domain entfällt. `.env` dafür:

```env
API_BASE_URL_USER=https://app.meinedomain.de/api
API_BASE_URL_KUNDE=https://portal.meinedomain.de/api
```

Jede App ruft die API dann same-origin über die eigene Domain auf — CORS
spielt in diesem Setup keine Rolle mehr, `CORS_ORIGIN` kann auf die
User-App-Domain gesetzt bleiben (dient nur als Absicherung, falls doch einmal
direkt aufs Backend zugegriffen wird).

---

## E-Mail-Benachrichtigungen (optional)

saasERP sendet E-Mails für:
- Neue Angebote/Rechnungen an Endkunden
- Angebotsentscheidungen an Mandanten-Inhaber
- Dunning-/Mahnungs-Benachrichtigungen
- Willkommens-E-Mails bei Registrierung
- Weiterleitung von Support-Anfragen

Konfiguration in `.env`:

```env
SMTP_HOST=smtp.meinanbieter.de
SMTP_PORT=587
SMTP_USERNAME=noreply@meinedomain.de
SMTP_PASSWORD=<smtp_passwort>
SMTP_FROM=noreply@meinedomain.de
SMTP_USE_SSL=false   # true für Port 465 (direktes SSL)

SUPPORT_EMAIL=support@meinedomain.de
```

Wenn `SMTP_HOST` leer bleibt, werden E-Mails nur in den Container-Logs protokolliert (kein Versand).

---

## Automatische Datenbank-Backups

saasERP enthält ein Backup-Skript (`backup/backup.sh`), das die PostgreSQL-Datenbank als komprimiertes SQL-Dump sichert.

### Einmaliges Backup ausführen

```bash
docker-compose --profile backup run --rm backup
```

Das Backup wird unter `./backup_data/<datenbankname>_<timestamp>.sql.gz` abgelegt.

### Automatisierung via Cron

Trage auf dem Host-System einen Cron-Job ein (täglich 03:00 Uhr):

```
0 3 * * * cd /opt/saaserp && docker-compose --profile backup run --rm backup >> /var/log/saaserp-backup.log 2>&1
```

### Aufbewahrungsdauer

```env
BACKUP_RETENTION_DAYS=30   # Backups älter als 30 Tage werden gelöscht
```

---

## Updates

```bash
git pull
docker-compose up -d --build
```

Datenbankmigrationen werden beim Backend-Start automatisch angewendet. Ein manuelles Eingreifen ist nicht erforderlich.

---

## Monitoring

Der Health-Endpunkt des Backends liefert den aktuellen Status inkl. Datenbankverbindung:

```bash
curl http://localhost:8080/
# {"service":"saasERP backend","status":"ok","db":"ok","timestamp":"..."}
```

Bei DB-Ausfall: HTTP 503 mit `"status":"degraded"`.

---

## Datensicherung und DSGVO

- **Mandantendaten** werden in der PostgreSQL-Datenbank gespeichert. PII-Felder (E-Mail, Telefon, Adresse) sind mit **Envelope-Encryption** (AES-256-CBC) pro Mandant verschlüsselt — der `ENCRYPTION_MASTER_KEY` entschlüsselt die mandantenspezifischen Datenschlüssel.
- **`ENCRYPTION_MASTER_KEY` sichern**: Ohne diesen Key sind die verschlüsselten PII-Felder nicht wiederherstellbar. Key und Backup getrennt aufbewahren.
- **Kein externer Datenzugriff** im Self-Hosting-Betrieb — alle Daten bleiben auf deinem Server.

---

## Fehlerbehebung

### Container startet nicht / Migrationen schlagen fehl

```bash
docker-compose logs backend
```

Häufige Ursachen:
- PostgreSQL noch nicht bereit: Wartet kurz und versucht es erneut (der Backend-Container hat einen eingebauten Retry-Mechanismus)
- Falsche Datenbankverbindungsdaten in `.env`

### E-Mails werden nicht gesendet

Prüfe die Container-Logs auf `[EmailService]`-Einträge:

```bash
docker-compose logs backend | grep EmailService
```

### Ports belegt

Die Standard-Ports (`8080`, `8081`, `8082`) können in `.env` geändert werden:

```env
BACKEND_PORT=9080
APP_USER_PORT=9081
APP_KUNDE_PORT=9082
```

---

## Support

- **GitHub Issues:** https://github.com/KayBeckmann/saasERP/issues
- **E-Mail:** Nutze das Kontaktformular unter `POST /api/support/contact` oder konfiguriere `SUPPORT_EMAIL` in deiner Instanz
