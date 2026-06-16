# Datenschutzerklärung — saasERP

> **Hinweis:** Dieser Entwurf basiert auf den DSGVO-Anforderungen (Art. 13/14) für eine B2B-SaaS-Plattform. Vor der Veröffentlichung durch einen Datenschutzexperten prüfen lassen. Platzhalter `[...]` ausfüllen.

---

## 1. Verantwortlicher

Verantwortlicher im Sinne der Datenschutz-Grundverordnung (DSGVO):

[VOLLSTÄNDIGER NAME / FIRMENNAME]
[STRAßE UND HAUSNUMMER]
[PLZ ORT]
Deutschland

E-Mail: [EMAIL]
Telefon: [TELEFONNUMMER]

---

## 2. Grundsätze der Datenverarbeitung

Wir verarbeiten personenbezogene Daten nur, soweit dies für die Bereitstellung des Dienstes saasERP erforderlich ist. Die Verarbeitung erfolgt ausschließlich auf Grundlage einer einschlägigen Rechtsgrundlage (Art. 6 DSGVO) und im Einklang mit dem Grundsatz der Datensparsamkeit.

---

## 3. Verarbeitung bei der Registrierung und Nutzung

### 3.1 Mandanten-Account (Betreiber-/Unternehmens-Daten)

Bei der Registrierung und Nutzung von saasERP verarbeiten wir folgende Daten:

| Datenkategorie | Zweck | Rechtsgrundlage |
|---|---|---|
| Name, E-Mail-Adresse, Passwort-Hash | Authentifizierung, Kontaktaufnahme | Art. 6 Abs. 1 b) DSGVO (Vertragserfüllung) |
| Firmenname, Adresse, USt-IdNr. | Vertragserfüllung, Rechnungsstellung | Art. 6 Abs. 1 b) DSGVO |
| IP-Adresse, Browser-Informationen | Sicherheit, Missbrauchsprävention | Art. 6 Abs. 1 f) DSGVO (berechtigtes Interesse) |
| Zahlungsdaten (Zahlungsweg, Zeitpunkt) | Abrechnungsnachweis, Buchhaltung | Art. 6 Abs. 1 b) / c) DSGVO |
| Nutzungsprotokoll (Server-Logs) | Fehlerdiagnose, Sicherheit | Art. 6 Abs. 1 f) DSGVO (berechtigtes Interesse) |

### 3.2 Kundendaten der Mandanten (Auftragsverarbeitung)

saasERP ist ein Werkzeug für Handwerksbetriebe und ähnliche Unternehmen. Die Daten, die ein Mandant über seine eigenen Kunden, Aufträge und Mitarbeiter in saasERP eingibt, verarbeiten wir ausschließlich im Auftrag des Mandanten (Art. 28 DSGVO). In diesem Verhältnis ist der Mandant der Verantwortliche; wir sind Auftragsverarbeiter. Die rechtliche Grundlage hierfür ist der gesondert abzuschließende **Auftragsverarbeitungsvertrag (AVV)**.

---

## 4. Datenspeicherung und -sicherheit

### 4.1 Speicherort

Alle Daten werden ausschließlich auf Servern in [SERVERSTANDORT, z. B. "Deutschland / EU"] gespeichert. Eine Übermittlung in Drittländer (außerhalb der EU/EWR) findet nicht statt.

### 4.2 Speicherdauer

- Vertragsdaten und Abrechnungsunterlagen: 10 Jahre (gesetzliche Aufbewahrungspflicht § 147 AO)
- Server-Logs: [30/90] Tage
- Mandantendaten nach Vertragsende: [30] Tage, danach unwiderrufliche Löschung

### 4.3 Technisch-organisatorische Maßnahmen (TOMs)

- Verschlüsselung der Datenübertragung via TLS (HTTPS)
- Verschlüsselung sensibler Felder in der Datenbank
- Passwörter werden ausschließlich als bcrypt-Hashes gespeichert
- Tägliche automatisierte Datensicherungen mit [30]-tägiger Aufbewahrung
- Zugangskontrolle via JWT-Token mit Rollen (Owner/Employee/Customer)
- Regelmäßige Updates der eingesetzten Software-Komponenten

---

## 5. Weitergabe von Daten

Eine Weitergabe personenbezogener Daten an Dritte erfolgt nur:

- **Auftragsverarbeiter:** Wir setzen ggf. externe Dienstleister als Auftragsverarbeiter ein (z. B. Hosting-Provider: [ANBIETER, LAND]). Mit diesen wurde ein AVV nach Art. 28 DSGVO abgeschlossen.
- **E-Mail-Versand:** Für den Versand von Transaktions-E-Mails (Angebots-/Rechnungsbenachrichtigungen, Willkommens-E-Mails) setzen wir [SMTP-ANBIETER, z. B. eigener Server / Mailgun] ein.
- **Gesetzliche Verpflichtungen:** Bei gesetzlicher Verpflichtung (z. B. Behördenauskunft nach richterlicher Anordnung).

Wir verkaufen keine personenbezogenen Daten an Dritte.

---

## 6. Cookies und lokale Speicherung

saasERP verwendet:

- **Session-Token (JWT):** Wird im Local Storage des Browsers gespeichert und enthält ausschließlich technisch notwendige Informationen (Tenant-ID, Benutzer-ID, Rolle, Ablaufzeit). Kein Tracking-Cookie.
- **Keine Analyse-Cookies:** Wir verwenden keine Tracking-, Werbe- oder Analyse-Cookies (kein Google Analytics, keine Drittanbieter-Tracker).

---

## 7. Rechte der betroffenen Personen

Betroffene Personen haben gegenüber uns folgende Rechte:

| Recht | Rechtsgrundlage |
|---|---|
| Auskunft über gespeicherte Daten | Art. 15 DSGVO |
| Berichtigung unrichtiger Daten | Art. 16 DSGVO |
| Löschung ("Recht auf Vergessenwerden") | Art. 17 DSGVO |
| Einschränkung der Verarbeitung | Art. 18 DSGVO |
| Datenübertragbarkeit | Art. 20 DSGVO |
| Widerspruch gegen Verarbeitung auf Basis berechtigter Interessen | Art. 21 DSGVO |

Zur Geltendmachung dieser Rechte wenden Sie sich per E-Mail an: [EMAIL]

**Beschwerderecht:** Sie haben das Recht, sich bei einer Datenschutz-Aufsichtsbehörde zu beschweren. Die zuständige Behörde für [BUNDESLAND] ist: [BEHÖRDENNAME + WEBSEITE].

---

## 8. Auftragsverarbeitungsvertrag (AVV)

Als Mandant von saasERP verarbeiten Sie personenbezogene Daten Ihrer Kunden und Mitarbeiter mithilfe unserer Plattform. In diesem Verhältnis sind wir Ihr Auftragsverarbeiter gemäß Art. 28 DSGVO. Wir schließen mit jedem Mandanten einen AVV ab. Den AVV finden Sie unter [LINK / als Anlage zum Registrierungsvertrag].

---

## 9. Änderungen dieser Datenschutzerklärung

Wir behalten uns vor, diese Datenschutzerklärung bei Änderungen des Dienstes oder der gesetzlichen Anforderungen anzupassen. Die jeweils aktuelle Version ist in saasERP unter [LINK] einsehbar. Bei wesentlichen Änderungen informieren wir Mandanten per E-Mail.

---

*Stand: [DATUM] — Entwurf, datenschutzrechtlich zu prüfen vor Veröffentlichung*
