# saasERP — Lizenz- und Support-Modell für Self-Hoster

Dieses Dokument beschreibt das Lizenz- und Support-Modell für Betreiber, die saasERP eigenständig hosten (On-Premises oder auf eigenem VPS).

---

## Lizenz

saasERP ist unter der **MIT-Lizenz** veröffentlicht.

Das bedeutet:
- Kostenlose Nutzung, auch kommerziell
- Weiterverbreitung erlaubt (mit Lizenzhinweis)
- Änderungen erlaubt
- Keine Copyleft-Pflicht (keine Verpflichtung, Änderungen zu veröffentlichen)
- Keine Garantie und keine Haftung des Lizenzgebers

Der vollständige Lizenztext befindet sich in der Datei `LICENSE` im Projekt-Root.

---

## Self-Hosting — was ist enthalten?

| Bestandteil | Enthalten |
|---|---|
| Quellcode (Backend, App-User, App-Kunde, Shared) | ✅ vollständig |
| Docker-Compose-Setup | ✅ |
| Datenbankmigrationen (automatisch beim Start) | ✅ |
| Backup-Skript (`backup/backup.sh`) | ✅ |
| Benutzerhandbuch (`docs/BENUTZERHANDBUCH.md`) | ✅ |
| Self-Hosting-Anleitung (`docs/SELF-HOSTING.md`) | ✅ |
| Technischer Support durch den Autor | ❌ (Community-Support via GitHub Issues) |
| Regelmäßige Updates | ❌ (Self-Hoster aktualisieren manuell per `git pull`) |

---

## Support-Optionen

### Community-Support (kostenlos)

- **GitHub Issues:** https://github.com/KayBeckmann/saasERP/issues
- **Scope:** Bugs, Fragen zur Installation, Konfigurationsprobleme
- **Antwortzeit:** Best-effort, keine Garantie

### Kommerzieller Support (optional, auf Anfrage)

Gegen Aufwandsentschädigung kann der Autor folgende Leistungen erbringen:

| Leistung | Beispiel-Scope |
|---|---|
| **Einrichtungshilfe** | Initiales Setup auf dem eigenen Server, inkl. Domain, TLS, SMTP |
| **Individuelle Anpassungen** | Zusätzliche Felder, branchenspezifische Anpassungen |
| **Schulung** | Einweisung der Mitarbeiter in die Nutzung von saasERP |
| **Migrationsunterstützung** | Import bestehender Kunden-/Artikel-Stammdaten |
| **Prioritäts-Bugfixing** | Kritische Fehler kurzfristig beheben |

Anfragen bitte per E-Mail an: [EMAIL]

---

## Managed SaaS vs. Self-Hosting — Vergleich

| Merkmal | Managed SaaS (saasERP.de) | Self-Hosting (MIT) |
|---|---|---|
| Kosten | Monatsgebühr (Tier-abhängig) | Serverkosten + Eigenaufwand |
| Updates | Automatisch | Manuell per `git pull` + `docker-compose up` |
| Backup | Automatisch, täglich | Eigenverantwortlich (`backup.sh`) |
| Support | E-Mail-Support (Owner-Tier) | Community / kostenpflichtig |
| Datenschutz | Daten beim Anbieter (AVV) | Vollständige Datensouveränität |
| Einrichtungsaufwand | Minimal (nur Registrierung) | Setup-Kenntnisse erforderlich |

---

## Frequently Asked Questions (Self-Hosting)

**Darf ich saasERP für mein eigenes Handwerksunternehmen kostenlos nutzen?**
Ja, uneingeschränkt — die MIT-Lizenz erlaubt die kostenlose kommerzielle Nutzung.

**Darf ich saasERP meinen Kunden anbieten (als eigene SaaS-Instanz weiterverkaufen)?**
Ja, die MIT-Lizenz erlaubt das. Du musst lediglich den ursprünglichen Lizenzhinweis beibehalten.

**Muss ich Änderungen am Code veröffentlichen?**
Nein. Die MIT-Lizenz enthält keine Copyleft-Pflicht.

**Gibt es eine Enterprise-Lizenz mit erweiterten Garantien?**
Auf Anfrage — schreib eine E-Mail an [EMAIL].

---

*Stand: [DATUM]*
