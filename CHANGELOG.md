# Changelog

## 1.2 – 11. Oktober 2026

### Neu
- **Tag abschließen:** Ein Button am Ende der Tagesliste lässt die KI (derselbe Anbieter und Schlüssel wie bei der Foto-Erkennung) fehlende Mikronährstoffe für alle Einträge ergänzen – Barcode-Produkte, KI-Scans, eigene Lebensmittel und Rezept-Zutaten. Etikett- und BLS-Werte bleiben unverändert, der Health Score rechnet danach mit den vollständigen Werten.
- **Tagesfazit:** Nach dem Abschluss ordnet die KI den Tag in 1–2 Worten ein; ein Tipp darauf zeigt Stichpunkte zu dem, was gut lief, was fehlte, und Tipps für morgen. Ändert sich der Tag danach, wird das Fazit als „veraltet“ markiert und lässt sich neu bewerten.

### Verbessert
- **Mitternacht:** „Heute“ wechselt um 0 Uhr automatisch auf den neuen Tag, Widgets zeigen ab Mitternacht den leeren neuen Tag.
- **Sicherung** enthält jetzt auch die Zutaten von Mahlzeiten und die Tagesfazits.
- **API-Schlüssel:** Leerzeichen und Zeilenumbrüche beim Einfügen werden ignoriert; Gemini-Schlüssel werden bei Bedarf auf zweitem Weg übergeben.

## 1.1 – 10. Oktober 2026

### Neu
- **Mahlzeiten mit Zutaten:** Rezepte und KI-Scans bleiben ein Eintrag unter „Gegessen“, lassen sich aber über einen Pfeil in der Karte ausklappen. Die Zutaten erscheinen als eigene, verbundene Zeilen – antippen öffnet dieselbe Bearbeiten-Ansicht wie bei normalen Einträgen, Wischen löscht bzw. trägt „Nochmal“ ein.
- **„Mahlzeit bearbeiten“** sieht aus und funktioniert wie die Gegessen-Liste; Zutaten können aus der Datenbank oder manuell ergänzt werden, Änderungen gelten sofort.
- **Rezept-Zutaten selbst eintragen** (Name, Menge, Nährwerte) zusätzlich zur Datenbanksuche.
- **Optionsmenü unter „Gegessen“:** Übernehmen von gestern oder einem anderen Tag, Einträge auswählen, Tag als Rezept speichern, alle zu Favoriten, Nährstoffe des Tages.
- **Auswahlmodus:** mehrere Einträge auf einmal löschen, auf einen anderen Tag kopieren oder als Rezept speichern.
- **Übernehmen mit Auswahl:** vor dem Kopieren eines Tages einzelne Einträge abwählen, inkl. „Alle an/aus“.
- **„Direkt eintragen“** in der Leiste über der Tastatur beim Eingeben von Mengen.
- **Reiter beim Hinzufügen:** Zuletzt · Favoriten · Meine nebeneinander statt untereinander.
- **Überschrift antippen:** an einem anderen Tag springt sie zu Heute, an Heute öffnet sie den Kalender.
- **Neuer Ladebildschirm** mit fallender Katze, Pixel-Schriftzug, laufender Katze auf dem Ladebalken und funkelnden Sternen.

### Verbessert
- **Verlauf:** „Ziel eingehalten“ passt sich dem Zeitraum an (Woche als Tagesreihe, 30/90 Tage als Raster); der Monatskalender ist über „Monat“ erreichbar.
- **Woche Montag–Sonntag** im Verlauf und im Kalender; der Wochen-Zeitraum zeigt die aktuelle Kalenderwoche.
- **Drei Zielfarben:** Grün im Ziel, Orange bis 5 % darüber, Rot mehr als 5 % darüber – im Raster, im Kalender und in den Diagrammen.
- **Barcode-Scanner:** der Blitz geht aus, sobald ein Code erkannt wurde.
- **App-Icon:** eigene Varianten für dunkle und eingefärbte Icons mit transparentem Hintergrund.
- **Widgets im transparenten/eingefärbten Modus:** Ring und Balken mit sichtbarem Hintergrund, die Katze in Helligkeitsstufen wie auf dem Sperrbildschirm.

## 1.0
- Erste Version: Tagesliste ohne Mahlzeiten-Kategorien, Bundeslebensmittelschlüssel 4.0 offline, Open Food Facts für Barcodes, Foto-Erkennung (Apple Intelligence, optional Gemini/Claude/OpenAI), Health Score, eigene Lebensmittel und Rezepte, Wasser, Gewicht mit Apple Health, Widgets, Backup und CSV-Export, Hell- und Dunkelmodus im Pixel-Katzen-Look.
