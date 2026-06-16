# saasERP — Benutzerhandbuch

Dieses Handbuch erklärt die wichtigsten Abläufe in saasERP. Es richtet sich an Handwerksbetriebe, die saasERP als Mandant nutzen.

---

## Erste Schritte

### Registrierung

1. Öffne die **User-App** (vom Betreiber mitgeteilte URL, z. B. `https://app.meinedomain.de`)
2. Klicke auf **Registrieren**
3. Gib deinen Firmennamen, deine E-Mail-Adresse und ein sicheres Passwort ein
4. Nach der Registrierung bist du direkt angemeldet und erhältst eine Willkommens-E-Mail

### Firmendaten konfigurieren

Bevor du Belege erstellst, hinterlege deine Firmendaten:

1. Im **Dashboard** die Karte **Firmendaten** aufklappen
2. Firmenadresse, USt-IdNr. und Standard-Mehrwertsteuersatz eintragen
3. Optional: Logo-URL für den Briefkopf hinterlegen
4. **Speichern** klicken

---

## Stammdaten

### Kunden anlegen

1. Navigation: **Kunden**
2. Button **Neuer Kunde**
3. Name (Pflicht), Adresse, E-Mail, Telefon, Notizen eingeben
4. **Kundenart**: Privat / Firma / Behörde wählen
5. Für B2G-Kunden (öffentliche Auftraggeber): **Leitweg-ID** eintragen — diese wird für E-Rechnungen (XRechnung) benötigt
6. **Speichern** → Kundennummer wird automatisch vergeben (K0001, K0002, ...)

### Lieferanten anlegen

Navigation: **Lieferanten** → **Neuer Lieferant**

Felder: Name, Ansprechpartner, IBAN, Zahlungsziel (Tage), Adresse, Notizen.

### Artikel anlegen

Navigation: **Artikel** → **Neuer Artikel**

Felder: Bezeichnung, SKU (Artikelnummer des Lieferanten), Einheit (z. B. "Stk", "m", "h"), EK-Preis, VK-Preis, Mehrwertsteuersatz, aktueller Lagerbestand, Mindestbestand.

**Tipp:** Wähle einen Standard-Lieferanten pro Artikel — dann erscheinen Artikel automatisch im Bestellvorschlag, wenn ein Auftrag abgewickelt wird.

### Preislisten importieren

Großhändler stellen häufig Preislisten als CSV-Dateien bereit:

1. Navigation: **Artikel** → **Preisimport**
2. CSV-Inhalt einfügen (Format: `SKU;Einkaufspreis`, Semikolon-getrennt, Kopfzeile wird erkannt)
3. **Importieren** — EK-Preise der erkannten Artikel werden aktualisiert
4. Für Produkte, die betroffene Artikel enthalten, erscheint ein Preisvorschlag zur Bestätigung

### Produkte anlegen

Produkte bündeln Artikel und Arbeitszeit zu einem festen Verkaufspreis:

Navigation: **Produkte** → **Neues Produkt**

- Bezeichnung und Verkaufspreis eingeben
- Komponenten hinzufügen: **Artikel** (mit Menge) oder **Arbeit** (Stunden zu einem Stundensatz)
- Die Gesamtkosten werden live berechnet

---

## Belegfluss: Angebot → Auftrag → Rechnung

### Angebot erstellen

1. Navigation: **Angebote** → **Neues Angebot**
2. Titel und Kunde wählen (optional)
3. Positionen hinzufügen:
   - **Freitext**: freie Beschreibung mit Preis
   - **Artikel**: Artikel aus dem Stamm wählen — Beschreibung und Preis werden übernommen
   - **Produkt**: Produkt aus dem Stamm wählen
   - **Stunden**: Stundenanzahl und Stundensatz eingeben
4. **Positionsgruppen** (optional): jeder Position eine Gruppe zuordnen (z. B. "Elektroinstallation") — Zwischensummen erscheinen automatisch
5. Status auf **Versendet** setzen, wenn das Angebot raus geht

**PDF erstellen:** Klicke auf das PDF-Symbol in der Angebotsliste oder im Editor.

### Angebot in Auftrag wandeln

Nach Annahme durch den Kunden:

1. In der **Angebotsliste** auf das Auftragssymbol klicken
2. Alle Positionen werden übernommen — der Auftrag erhält eine eigene Nummer (AU0001, ...)

### Rechnung aus Auftrag erstellen

1. In der **Auftragsliste** auf das Rechnungssymbol klicken
2. **Rechnungsart** wählen:
   - **Standard**: vollständige Abrechnung aller Positionen
   - **Teilrechnung**: nur ausgewählte Positionen abrechnen
   - **Abschlagsrechnung**: wie Teilrechnung, aber als Anzahlung gekennzeichnet
   - **Schlussrechnung**: verbleibende Positionen, Vorleistungen werden automatisch abgezogen
3. Bereits abgerechnete Positionen sind ausgegraut (Doppelabrechnungsschutz)
4. Fälligkeitsdatum setzen und **Speichern**

**Tipp:** Schlussrechnungen berechnen `prior_invoiced_total` automatisch aus allen zugehörigen Vor-Rechnungen.

### Rechnung als PDF / E-Rechnung exportieren

- **PDF**: Klicke auf das PDF-Symbol in der Rechnungsliste
- **ZUGFeRD/XRechnung** (für B2B/B2G): Klicke auf das XML-Symbol → Download als `R0001-facturx.xml`

---

## Mahnwesen

Überfällige Rechnungen:

1. Navigation: **Mahnwesen** — listet alle Rechnungen, bei denen `Fälligkeitsdatum < heute` und Status nicht bezahlt/storniert
2. Button **Mahnung erstellen** → die Mahnstufe wird erhöht (1: Zahlungserinnerung, 2: 1. Mahnung, 3: 2. Mahnung)
3. **Mahngebühren** sind unter **Firmendaten → Mahngebühren** pro Stufe konfigurierbar
4. Danach **Mahnungs-PDF** herunterladen und versenden

---

## Bestellwesen

### Bestellvorschlag aus Auftrag

1. In der **Auftragsliste** auf das Bestellvorschlags-Symbol klicken
2. Es erscheint eine Aufstellung des Materialbedarfs nach Lieferant (Bedarf − Lagerbestand = Fehlmenge)
3. Lieferanten-Gruppe wählen → Bestellformular öffnet sich vorausgefüllt

### Bestellung anlegen

Navigation: **Bestellungen** → **Neue Bestellung**

Lieferant wählen, Positionen (Artikel oder Freitext) hinzufügen.

### Wareneingang buchen

Im Bestellformular: Je Position die tatsächlich gelieferte Menge eintragen → **Wareneingang buchen**. Der Lagerbestand wird automatisch aktualisiert.

---

## Projektverwaltung

Projekte bündeln mehrere Aufträge, Bestellungen und Stunden zu einer Baustelle oder einem größeren Vorhaben.

### Projekt anlegen

Navigation: **Projekte** → **Neues Projekt** → Titel, Kunde (optional), Notizen.

### Aufträge und Bestellungen einem Projekt zuordnen

Beim Anlegen oder Bearbeiten eines Auftrags / einer Bestellung: Feld **Projekt** wählen.

### Gewinn/Verlust-Übersicht

Im **Projektdetail** erscheint eine Auswertung:
- **Einnahmen**: Summe aller Rechnungen zu diesem Projekt + sonstige Einnahmen
- **Kosten**: Materialkosten (Bestellungen) + Stundenkosten (Stunden × Stundensatz aus Firmendaten) + sonstige Kosten
- **Gewinn** = Einnahmen − Kosten

---

## Stundenerfassung

Navigation: **Stundenerfassung** — Wochenansicht mit je einem Tag-Eintrag.

- **Woche navigieren**: Pfeile in der AppBar
- **Stunden erfassen**: `+`-Button im jeweiligen Tag → Stunden, optionaler Auftragsbezug, Beschreibung

Monatliche Gesamtstunden erscheinen im Dashboard.

---

## Kundenportal einrichten

Kunden können über das **Kundenportal** (Kunden-App) Angebote freigeben, Rechnungen einsehen und Dokumente hochladen.

### Kundenzugang anlegen

1. Navigation: **Kunden** — Klicke auf das Zugangs-Symbol (Personalausweis-Icon) neben dem Kunden
2. Dialog öffnet sich: **Zugang anlegen** — die E-Mail-Adresse des Kunden wird übernommen
3. Ein **Einladungslink** wird erzeugt → Link kopieren und an den Kunden senden
4. Der Kunde klickt auf den Link, vergibt ein Passwort und kann sich anmelden

### Was Kunden im Portal sehen

- Ihre Angebote — und können sie direkt **freigeben** oder **ablehnen** (mit Kommentar)
- Ihre Rechnungen mit Zahlungsstatus und PDF-Download
- Ihre Wartungsverträge mit Kündigungsfrist und Vertragsstrafen-Vorschau
- Können Dokumente (Fotos, Pläne) hochladen

---

## Wartungsverträge

Navigation: **Wartungsverträge** → **Neuer Vertrag**

Felder: Kunde, Bezeichnung, Laufzeit (Monate), Start-/Enddatum, Kündigungsfrist (Monate), maximale Vertragsstrafe, Notizen.

**Kündigung:** Im Bearbeitungsmodus Status auf "Gekündigt" setzen und Kündigungsdatum wählen. Die Vertragsstrafe wird automatisch berechnet: `Strafe = max. Strafe × Restlaufzeit / Gesamtlaufzeit`.

---

## Mehrbenutzer-Betrieb

Als **Owner** kannst du weitere Benutzer einladen:

- Rolle **Employee**: vollständiger Zugriff auf alle ERP-Funktionen im Mandanten
- Rolle **Owner**: zusätzlich Firmenkonfiguration, Mahngebühren-Einstellungen

*(Benutzer-Einladung via direkter Registrierung mit derselben Domain; Rollen-Zuweisung im Multi-Tenant-Zugangsmanagement — Funktion ist im Backend vorhanden, dedizierter UI-Screen folgt.)*

---

## Steuerberater-Export

Navigation: **Dashboard** → Button **Steuerberater-Export (CSV)**

- Optional: Von/Bis-Zeitraum wählen
- Download als CSV (Semikolon-getrennt, deutsches Dezimalkomma)
- Spalten: Rechnungsnummer, Rechnungsdatum, Fälligkeitsdatum, Kunde, Rechnungstyp, Status, Netto, USt., Brutto

---

## Häufige Fragen

**Wie ändere ich mein Passwort?**
Die Passwortänderung ist noch nicht über das Frontend verfügbar. Bitte wende dich an den saasERP-Betreiber.

**Was bedeutet der rote „unter Mindestbestand"-Hinweis in der Bestandsübersicht?**
Der Lagerbestand dieses Artikels ist unter den hinterlegten Mindestbestand gefallen. Es empfiehlt sich eine Nachbestellung.

**Kann ich den Stundensatz für die Projektkalkulation anpassen?**
Ja: **Dashboard** → **Firmendaten** → Feld **Stundensatz für Projekt-Auswertung (€/h)**. Dieser Satz gilt für alle Projekte des Mandanten.

**Was ist der Unterschied zwischen ZUGFeRD und XRechnung?**
- **XRechnung** ist XML-nur und Pflicht für Rechnungen an öffentliche Auftraggeber (B2G) in Deutschland.
- **ZUGFeRD** ist eine PDF-plus-XML-Kombination für B2B. saasERP exportiert das XML-Teil (Factur-X Basic), das mit gängigen Buchhaltungsprogrammen (DATEV, Lexoffice) importiert werden kann.

**Wie bekommen Kunden ihre Rechnungen per E-Mail?**
Wenn ein SMTP-Server konfiguriert ist und der Kunde einen Kundenportal-Zugang hat, erhält er automatisch eine E-Mail, sobald eine Rechnung auf "Versendet" gesetzt wird.
