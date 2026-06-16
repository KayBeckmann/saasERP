# Auftragsverarbeitungsvertrag (AVV) — saasERP

> **Hinweis:** Dieser Entwurf entspricht den Anforderungen von Art. 28 DSGVO für einen B2B-SaaS-Auftragsverarbeitungsvertrag. Vor der Verwendung durch einen Datenschutzexperten und/oder Rechtsanwalt prüfen lassen. Platzhalter `[...]` ausfüllen.

---

## Präambel

Der Auftragnehmer (saasERP-Betreiber) erbringt für den Auftraggeber (Mandant) Leistungen, bei deren Durchführung der Auftragnehmer personenbezogene Daten verarbeitet, für die der Auftraggeber der datenschutzrechtliche Verantwortliche im Sinne der DSGVO ist.

Die Parteien schließen diesen Auftragsverarbeitungsvertrag (AVV) gemäß Art. 28 Abs. 3 DSGVO als Ergänzung zum Nutzungsvertrag für saasERP.

---

## § 1 Gegenstand und Dauer der Verarbeitung

1. Der Auftragnehmer verarbeitet personenbezogene Daten im Auftrag des Auftraggebers gemäß Art. 28 DSGVO ausschließlich zum Zweck der Bereitstellung des Dienstes saasERP und nur nach dokumentierten Weisungen des Auftraggebers.

2. Die Dauer der Verarbeitung entspricht der Laufzeit des Nutzungsvertrags. Nach Vertragsende werden die Daten gemäß § 9 dieses AVV behandelt.

---

## § 2 Art und Zweck der Verarbeitung

**Art der Verarbeitung:** Speicherung, Übermittlung, Anzeige, Sicherung, Löschung von Daten, die der Auftraggeber über die Nutzung des Dienstes saasERP eingibt.

**Zweck der Verarbeitung:** Betrieb der SaaS-Plattform saasERP — insbesondere Verwaltung von Kunden, Angeboten, Aufträgen, Rechnungen, Bestellungen, Wartungsverträgen und weiterer vom Auftraggeber eingegebener Geschäftsdaten.

**Kategorien betroffener Personen:**
- Kunden und Interessenten des Auftraggebers
- Lieferanten und Geschäftspartner des Auftraggebers
- Mitarbeiter des Auftraggebers (im Rahmen der Benutzerverwaltung)
- Endkunden im Kundenportal (sofern genutzt)

**Kategorien personenbezogener Daten:**
- Stammdaten (Name, Anschrift, Kontaktdaten)
- Vertragsdaten (Angebote, Aufträge, Rechnungen, Verträge)
- Zahlungsdaten (Zahlungsstatus, Fälligkeiten — keine Zahlungsinstrumentdaten wie Kontonummern)
- Kommunikationsdaten (E-Mail-Adressen für Benachrichtigungen)
- Zugangs- und Nutzungsdaten (Login-Daten, Zeiteinträge)

---

## § 3 Weisungsrecht

1. Der Auftragnehmer verarbeitet personenbezogene Daten ausschließlich nach dokumentierten Weisungen des Auftraggebers. Dieser AVV und der Nutzungsvertrag gelten als solche Weisung.

2. Weisungen des Auftraggebers, die über den vereinbarten Leistungsumfang hinausgehen, bedürfen der gesonderten Vereinbarung.

3. Ist der Auftragnehmer der Ansicht, dass eine Weisung gegen datenschutzrechtliche Vorschriften verstößt, unterrichtet er den Auftraggeber unverzüglich. Der Auftragnehmer ist berechtigt, die Ausführung der entsprechenden Weisung auszusetzen, bis der Auftraggeber die Weisung bestätigt oder geändert hat.

---

## § 4 Vertraulichkeit

1. Der Auftragnehmer stellt sicher, dass die zur Verarbeitung befugten Personen zur Vertraulichkeit verpflichtet wurden oder einer angemessenen gesetzlichen Verschwiegenheitspflicht unterliegen.

2. Der Auftragnehmer gewährt nur denjenigen Personen Zugang zu den Daten, die ihn für die Vertragserfüllung benötigen ("Need-to-Know-Prinzip").

---

## § 5 Technisch-organisatorische Maßnahmen (TOMs)

Der Auftragnehmer trifft alle erforderlichen Maßnahmen gemäß Art. 32 DSGVO. Die aktuell umgesetzten TOMs umfassen:

### Pseudonymisierung und Verschlüsselung
- Übertragungsverschlüsselung via TLS 1.2/1.3 (HTTPS) für alle Client-Server-Verbindungen
- Passwörter werden ausschließlich als bcrypt-Hashes gespeichert (nie im Klartext)
- Sensible Datenbankfelder (E-Mail-Adresse, Name in ausgewählten Kontexten) werden verschlüsselt gespeichert

### Integrität und Verfügbarkeit
- Tägliche automatisierte Datenbankbackups, 30-tägige Aufbewahrung
- Transaktionale Datenbankoperationen zur Konsistenzsicherung
- Health-Check-Monitoring mit Datenbankverbindungsprüfung

### Zugriffskontrolle
- JWT-basierte Authentifizierung mit Ablaufzeit
- Rollenbasierte Zugriffskontrolle (Owner / Employee / Customer / Platform-Admin)
- Mandantenisolation auf Datenbankebene (jede Query enthält tenant_id als Filter)

### Verfügbarkeit
- Containerisierte Deployment-Architektur (Docker)
- Fehlerüberwachung über Server-Logs

Der Auftragnehmer ist berechtigt, die TOMs weiterzuentwickeln, sofern das Schutzniveau nicht unterschritten wird. Wesentliche Änderungen werden dem Auftraggeber mitgeteilt.

---

## § 6 Unterauftragsverarbeiter

1. Der Auftraggeber erteilt dem Auftragnehmer die allgemeine Genehmigung, Unterauftragsverarbeiter einzusetzen. Der Auftragnehmer informiert den Auftraggeber über geplante Änderungen im Unterauftragnehmer-Einsatz und gibt dem Auftraggeber die Möglichkeit, Einwände zu erheben.

2. Aktuell eingesetzte Unterauftragsverarbeiter:

| Dienstleister | Leistung | Sitz |
|---|---|---|
| [HOSTING-ANBIETER] | Server-Hosting, Datenspeicherung | [EU/Deutschland] |
| [SMTP-ANBIETER, falls extern] | E-Mail-Versand | [EU/Deutschland] |

3. Unterauftragsverarbeitungen außerhalb der EU/EWR bedürfen der ausdrücklichen Zustimmung des Auftraggebers und sind nur bei Vorliegen geeigneter Garantien gemäß Art. 46 DSGVO zulässig. Aktuell findet keine Verarbeitung in Drittländern statt.

---

## § 7 Unterstützung des Auftraggebers

1. Der Auftragnehmer unterstützt den Auftraggeber bei der Erfüllung von Betroffenenanfragen (Auskunft, Berichtigung, Löschung) soweit möglich durch geeignete technische und organisatorische Maßnahmen.

2. Der Auftragnehmer unterstützt den Auftraggeber bei der Meldung von Datenschutzverletzungen an Aufsichtsbehörden (Art. 33 DSGVO) und der Benachrichtigung betroffener Personen (Art. 34 DSGVO).

3. Der Auftragnehmer informiert den Auftraggeber unverzüglich, wenn ihm eine Verletzung der Sicherheit personenbezogener Daten bekannt wird.

---

## § 8 Kontrollrechte des Auftraggebers

1. Der Auftragnehmer gestattet dem Auftraggeber Kontrollen der Einhaltung dieses AVV und ermöglicht diese. Kontrollen können durch den Auftraggeber selbst oder durch einen beauftragten Dritten (Datenschutzprüfer) durchgeführt werden.

2. Der Auftragnehmer ist berechtigt, Kontrollen durch Vorlage aktueller Zertifizierungen oder Prüfberichte anerkannter unabhängiger Stellen nachzuweisen, sofern diese den Prüfungsgegenstand abdecken.

3. Kontrollen beim Auftragnehmer sind mit angemessener Vorankündigungsfrist (mindestens 14 Tage) durchzuführen, um den laufenden Betrieb nicht unverhältnismäßig zu beeinträchtigen.

---

## § 9 Löschung und Rückgabe nach Vertragsende

1. Nach Beendigung des Nutzungsvertrags stellt der Auftragnehmer dem Auftraggeber alle verarbeiteten Daten in einem gängigen maschinenlesbaren Format (CSV/JSON) zur Verfügung und löscht anschließend alle Kopien, sofern keine gesetzlichen Aufbewahrungspflichten entgegenstehen.

2. Die Bereitstellung der Daten erfolgt auf Anforderung des Auftraggebers innerhalb von [30] Tagen nach Vertragsende. Danach werden die Daten des Auftraggebers unwiderruflich gelöscht.

3. Auf Wunsch des Auftraggebers bestätigt der Auftragnehmer die vollständige Löschung schriftlich.

---

## § 10 Schlussbestimmungen

1. Dieser AVV ist Bestandteil des Nutzungsvertrags für saasERP. Im Zweifel gehen die Regelungen dieses AVV den Regelungen des Nutzungsvertrags vor, soweit datenschutzrechtliche Belange betroffen sind.

2. Es gilt das Recht der Bundesrepublik Deutschland. Gerichtsstand ist [ORT DES AUFTRAGNEHMERS].

3. Änderungen dieses AVV bedürfen der Schriftform oder der Textform.

---

*Stand: [DATUM] — Entwurf, datenschutzrechtlich zu prüfen vor Verwendung*
