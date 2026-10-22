# Changelog

## 2.0 – Redesign (iPhone)

### Neu
- **Neue Navigation:** Heute, Verlauf, Profil (und Freunde, wenn aktiv) in der nativen Leiste.
- **Eintragen mit einem Tipp:** Suchen, Barcode, Foto und Schnell sitzen als neues Glas-Dock mit Beschriftung direkt über der Leiste auf „Heute“.
- **Neues Suchfenster:** Barcode, Foto und Schnell-Eintrag sind auch hier, dazu „Was passt noch?“ und Zuletzt/Favoriten/Meine.
- **Heute neu aufgebaut:** Wochenleiste mit Zielfarben statt Pfeilen, Serie im Kopf, eine große Karte mit Kalorienring, Katze und Makros, Health Score und Tagesfazit wie gewohnt, schmale Wasser-Zeile, Mahlzeiten mit Uhrzeit weiter oben. Leerer Tag mit vier Startoptionen.
- **Verlauf:** Kalorien-Diagramm zuerst, dann Serie, echter Verbrauch, Zielübersicht, Score und Gewicht. Seltener genutzte Auswertungen stehen unter „Weitere Auswertungen“. Zeiträume: Woche, Monat, 3 Monate.
- **Profil:** Einstellungen nach Aufgaben gruppiert (Darstellung, Funktionen, Apple Health, Freunde, Daten & Backup, Datenquellen & KI).
- **Einrichtung in vier Schritten:** Ziel, Eckdaten per Wheel-Picker, Aktivität, Tagesziel mit Apple-Health-Option.
- **Serie mit Streak-Freeze:** Die Serie sitzt oben rechts auf „Heute“ (grau, bis du heute etwas einträgst). Tippen öffnet die Serien-Ansicht mit Rekord, Freezes und den letzten fünf Wochen. Fehlt ein Tag, rettet ein Freeze die Serie automatisch. Alle 7 Tage in Folge gibt es einen neuen, maximal 2. Beim ersten Eintrag des Tages leuchtet die Flamme kurz auf, ohne dass du warten musst. Hat gestern ein Freeze die Serie gerettet und heute ist noch nichts eingetragen, wird aus der Flamme eine blaue Schneeflocke, und der Tag steht blau in der Wochenleiste.
- **Mehr Platz auf „Heute“:** Die Wochenleiste ist nicht mehr angeheftet und scrollt mit. Beim Runterscrollen klappt das Eintragen-Dock zu einem einzigen „Suchen“-Button zusammen (ein Tipp öffnet direkt die Suche) und kommt beim Hochscrollen zurück.
- **Einheitliche Typografie und Abstände:** vier Schriftgrößen, zwei Schriftstärken, weiche getönte Schatten.

## 1.8.1 – 22. Oktober 2026

### Neu
- **Server-Code wird beim Verbinden geprüft:** Nach „Verbinden“ fragt die App kurz beim Server nach (Ladeanzeige „Verbinde mit dem Server …“). Erst wenn alles stimmt, erscheint „Verbunden“. Bei einem falschen Code steht da, was nicht passt: falscher Schlüssel, Schlüssel und Projekt passen nicht zusammen, kein Freunde-Server im Projekt oder keine Verbindung. Gespeichert wird nur ein Code, der funktioniert.
- **Freunde-Server trennen:** Einstellungen → Freunde → „Freunde-Server trennen“. Dein Profil und dein Code werden vom bisherigen Server gelöscht, deine Einträge bleiben. Danach kannst du den Code eines anderen Servers einfügen. Auch Versionen mit eingebautem Server bleiben getrennt.

### Behoben
- **iPhone, „Server-Code teilen“:** öffnet jetzt zuverlässig das Teilen-Menü.

## 1.8 – 22. Oktober 2026

### Neu
- **Server-Code für die Freunde-Seite:** Die Freunde-Seite lässt sich jetzt mit einem Code einschalten. Einstellungen → Freunde → „Freunde-Server verbinden“, Code einfügen, „Verbinden“. Verbundene Apps können ihn unter „Server-Code teilen“ weitergeben. Gilt für iPhone und Android.
  - Auf dem iPhone ändert sich nichts: Der eingebaute Server wird beim ersten Start von 1.8 gespeichert. Konto, Code und Freunde bleiben.
  - Wer von einer Android-APK 1.7 bis 1.7.3 auf die öffentliche 1.8 wechselt, fügt den Code einmal ein. Die Freunde bleiben erhalten.
- **Android: App-Update in der App.** Einstellungen → App-Update → „Nach Updates suchen“ holt die neueste Version von GitHub. Vorher legt die App eine komplette Sicherung an und prüft, ob das Update wirklich zu deiner App gehört. Alle Einträge, Rezepte, Gewichte und Einstellungen bleiben erhalten. Einmal am Tag schaut die App selbst nach.
- **Öffentliche APK:** Die APK am GitHub-Release enthält keine Server-Daten mehr.

## 1.7.3 – 20. Oktober 2026

### Neu
- **Freunde, „Heute“ antippen:** zeigt die Aufschlüsselung des Tages mit Kalorien, Protein, Kohlenhydraten und Fett, jeweils gegen das eigene Ziel, plus die Verteilung der Kalorien. Von dort geht es weiter zum Vergleich. Die Makros sind sichtbar, sobald beide die neue Version haben.
- **Rezept erstellen:** Zutaten lassen sich per Barcode scannen (Symbol oben rechts), und bei leerem Suchfeld steht der Verlauf „Zuletzt verwendet“. Die Suche findet jetzt auch die Schweizer Datenbank und die Restaurantketten.

### Behoben
- **„Auswählen“ auf der Heute-Seite:** nach dem ersten Eintrag reagierten weitere Taps nicht zuverlässig. Jetzt ist im Auswahlmodus die ganze Zeile inklusive Kreis eine Tippfläche, ohne Menü oder Animation, die Taps abfängt.
- **„Was passt noch?“ über dem Ziel:** schlug trotzdem kleine Snacks vor und schrieb „Passt ins Budget“. Jetzt erscheinen nur noch Vorschläge, die wirklich in die restlichen Kalorien passen. Ist das Ziel erreicht, zeigt die Katze keine mehr.

## 1.7.2 – 18. Oktober 2026

### Behoben
- **Apple Health: Einträge mehrfach gezählt.** Bis 1.7.1 schrieb Purrtion die Einträge der letzten Tage bei jedem App-Start erneut in Apple Health, die Nährwerte der alten Fassung blieben dabei stehen. Dadurch waren kcal, Makros und Mikronährstoffe dort ein Vielfaches zu hoch. Jetzt:
  - Beim ersten Start von 1.7.2 löscht Purrtion alles, was es selbst in Apple Health eingetragen hat, und schreibt jeden erfassten Tag einmal sauber neu. Daten anderer Apps bleiben unberührt.
  - Unveränderte Einträge werden nicht mehr erneut geschrieben, jeder Nährwert hat eine eigene Kennung, und es läuft immer nur ein Abgleich gleichzeitig.
  - In Einstellungen gibt es zusätzlich „Ernährungsdaten in Health neu schreiben“, um das jederzeit selbst auszulösen.
- **Android, Health Connect:** geänderte Einträge wurden teils nicht aktualisiert. Jetzt bekommt jede Änderung eine höhere Version.
- GitHub-Releases wieder aktuell (der neueste Release zeigte noch 1.6). Die Android-APK hängt jetzt am Release.

## 1.7.1 – 15. Oktober 2026

### Neu
- **Partynacht über Mitternacht:** Getränke mit Alkohol, die zwischen 0 und 5 Uhr eingetragen werden, zählen automatisch zum Abend davor. So bleibt eine Nacht ein Abend: eine Promille-Kurve, eine Tagesbilanz, eine Tagesübersicht. Die echte Uhrzeit bleibt erhalten, die Kurve stimmt also weiter.
  - Beim Eintragen über die Suche erscheint „🌙 zählt zur Nacht von gestern“.
  - Im Schnell-Eintrag gibt es dafür einen Schalter („Zur Nacht von gestern zählen“), falls es doch zum neuen Tag gehören soll.
  - Essen ohne Alkohol (der Döner um 2 Uhr) bleibt beim neuen Tag.
  - Die automatische Tagesanalyse wartet nach einem Abend mit Getränken bis 5 Uhr, damit die ganze Nacht drin ist.
  - Katze und Freunde-Seite berücksichtigen auch die Getränke der Nacht davor beim aktuellen Promillewert.

## 1.7 – 15. Oktober 2026

### Neu
- **Android-App** (`android/`): Purrtion komplett neu in Kotlin und Jetpack Compose, ab Android 9.
  - Alle Funktionen der iPhone-App: Heute mit Katze, Suche (BLS, Schweizer Datenbank, Open Food Facts, KI), Barcode, Foto-Erkennung, Schnell-Eintrag, Rezepte und eigene Lebensmittel, Health Score, Tagesfazit, Promille, echter Verbrauch, Verlauf, Freunde, Teilen-Bilder und Widget.
  - Health Connect statt Apple Health (Gewicht, Aktivität, Ernährung), ML Kit für die Offline-Bilderkennung.
  - Sicherungen sind zwischen iPhone und Android austauschbar, Freunde auf beiden Plattformen sehen sich gegenseitig.
- **Restaurantketten** (iPhone und Android): McDonald's und Burger King mit rund 370 Produkten direkt in der Suche.
  - Offizielle Nährwerte der Ketten (Deutschland) mit echter Portionsgröße, also z. B. Whopper 282 g mit 613 kcal.
  - Kettenname in der Suche („mcdonalds pommes“, „bk whopper“, „mäcces“) zeigt die Kette zuerst, der Name allein die ganze Karte.
  - Funktioniert offline und wird wie BLS und die Schweizer Datenbank über GitHub aktualisiert. In Einstellungen → Datenquellen abschaltbar.
  - Neue Pixel-Symbole für Burger und Pommes.
- **Schnell eintragen „Pro 100 g“:** Umschalter oben im Schnell-Eintrag. Werte direkt aus der Nährwerttabelle der Packung eintippen, dann die gegessene Menge (mit Schnellwahl 30 bis 500 g). Purrtion rechnet die kcal und Makros aus und merkt sich den Modus.

- **Freunde verwalten:** neue Übersicht (Symbol oben links auf der Freunde-Seite, Knopf unten auf der Seite und in Einstellungen → Freunde). Freunde entfernen, gesendete Anfragen zurückziehen, Anfragen annehmen oder ablehnen. Wer abgelehnt oder entfernt wurde und weiter vergleichen möchte, steht unter „Abgelehnt oder entfernt“ und lässt sich wieder annehmen.

### Behoben
- **Angenommene Anfrage blieb bei „Anfrage gesendet“:** Wurde eine Anfrage angenommen, während die Freunde-Seite gerade im Hintergrund aktualisierte, konnte die ältere Freundesliste die Annahme auf dem Server überschreiben. Die eigene App zeigte trotzdem den Vergleich, die andere Seite nur „Anfrage gesendet“. Purrtion prüft jetzt nach jedem Hochladen, ob sich inzwischen etwas geändert hat, und schickt dann sofort den aktuellen Stand. Nicht angekommene Änderungen werden bei jedem App-Start erneut gesendet statt erst nach 15 Minuten.
- **Neue Einträge kamen bei Freunden nicht an:** Eigene Werte wurden höchstens alle 15 Minuten gesendet, und wer innerhalb dieser Zeit etwas eintrug, wurde danach nicht erneut versucht. Jetzt gehen neue, geänderte und gelöschte Einträge nach etwa 20 Sekunden raus (höchstens alle 2 Minuten, nur bei Änderungen), außerdem beim Verlassen der App und beim Herunterziehen der Freunde-Seite.
- **Antworten auf Anfragen erscheinen von selbst:** Solange Anfragen offen sind, schaut die Freunde-Seite alle 30 Sekunden und beim Öffnen der App nach. Ziehen zum Aktualisieren ist nicht mehr nötig.

### Verbessert
- **Gewicht eintragen:** − und + neben dem Regler ändern in 0,1-kg-Schritten (gedrückt halten wiederholt). Der Wert startet beim zuletzt eingetragenen Gewicht statt beim Profilgewicht. Auch im Profil gibt es − und + (0,5 kg).

## 1.6 – 14. Oktober 2026

### Neu
- **Freunde:** neuer Reiter (in den Einstellungen ausblendbar) zum Vergleichen mit Freunden.
  - Einladen per Link (öffnet Purrtion über eine kleine Webseite) oder 8-stelligem Code, Anfragen annehmen oder ablehnen.
  - **Heute:** gegessene kcal und Tagesziel aller Freunde.
  - **Rangliste** über zehn Kennzahlen: Serie, Tage im Ziel, Health Score, Protein, Wasser, Aktivität, Obst & Gemüse, Ballaststoffe, Zieltreue und Fleiß.
  - **Diese Woche:** die letzten 7 Tage aller in Zielfarben nebeneinander.
  - **Duell:** Punktestand und jede Kennzahl im direkten Vergleich.
  - Jeder Freund mit seiner Katzenfarbe und Tagesstimmung.
  - Einstellungen → Freunde: Name, Gewichtstrend teilen (standardmäßig aus), eigener Code, Freunde-Daten löschen.
  - Geteilt werden nur Kennzahlen und Tageskalorien, keine Mahlzeiten und kein Gewicht. Backend kostenlos auf Firebase, mit sehr wenigen Anfragen.

### Verbessert
- **Promille:** rechnet jetzt wie übliche Promillerechner mit 0,1 ‰ Abbau pro Stunde und 30 Minuten Aufnahme je Getränk (vorher 0,15 ‰ und 45 Minuten).
- Die stolze Katze hat jetzt richtige Herz-Augen.

## 1.5.1 – 13. Oktober 2026

### Verbessert
- **Einstellungen statt Profil:** Der dritte Reiter heißt jetzt „Einstellungen“ (Zahnrad). Darin gibt es den eigenen Abschnitt **„Dein Profil“** mit Geschlecht, Alter, Größe und Gewicht auf einen Blick.
- **Profil speichern ohne neues Ziel:** In „Dein Profil“ gibt es neben „Als Ziel übernehmen“ jetzt **„Nur Profil speichern“** – deine Angaben werden übernommen, das Kalorienziel bleibt unverändert. Änderungen werden erst beim Speichern übernommen.

## 1.5 – 13. Oktober 2026

### Neu
- **Echter Verbrauch** (Verlauf): Purrtion misst deinen tatsächlichen Tagesverbrauch aus dem, was du isst, und deinem Gewichtstrend der letzten Wochen – unabhängig von Formeln und Uhr. Der Gewichtstrend kommt aus einer robusten Regression (Ausreißer durch Wasser zählen kaum), der Energiegehalt pro Kilo hängt vom Körperfett ab (Forbes/Hall-Modell). Bei wenig Daten stützt sich der Wert auf Apple Health bzw. dein Profil, mit jeder Woche zählt die Messung mehr. Aufgeteilt in **Grundumsatz, Verdauung und Bewegung**, mit Genauigkeit (± kcal), Abgleich mit den Aktivitätskalorien aus Apple Health und einem Knopf, um das passende Kalorienziel zu übernehmen.
- **Was passt noch?** (Suche, Menü unter „Gegessen“, Tagesübersicht): Favoriten, Rezepte und eigene Lebensmittel, sortiert danach, wie gut Menge, Kalorien und Makros zum Rest des Tages passen. Wischen trägt direkt ein.
- **Promille** in der Tagesübersicht: Schätzung aus Geschlecht, Alter, Größe, Gewicht und der Uhrzeit jedes Getränks, mit Verlauf, Höchstwert, „unter 0,5 ‰ ab“ und „nüchtern ab“. Uhrzeiten lassen sich nachträglich anpassen.
- **Ernährung in Apple Health** (Profil): jeder Eintrag mit kcal, Makros und über 30 Mikronährstoffen sowie Wasser landet im Ernährungsprotokoll; Änderungen und Löschungen werden übernommen.
- **Schnell eintragen** mit Alkohol (ml + Vol-% oder Gramm, Uhrzeit, Vorlagen für Bier, Wein, Sekt, Shot) und allen Mikronährstoffen.
- **Mehr Katzen:** gähnt am Morgen, hungrig mit leerem Napf, beschwipst, durstig, mit Stirnband nach viel Sport, zufrieden, mit Herzaugen bei einem richtig guten Tag, kugelrund bei viel zu viel – und schläft nachts.

### Verbessert
- **Health Score:** Alkohol gibt einen Abzug (bis 20 Punkte), da es laut WHO keine unbedenkliche Menge gibt.
- **Selbst eingetragene Aktivität** zählt jetzt mit demselben Prozentsatz wie Apple Health (ohne Apple Health weiterhin voll).
- Das Health-Score-Diagramm im Verlauf zeigt Wochentage bzw. Daten statt Uhrzeiten.

## 1.4.1 – 12. Oktober 2026

### Neu
- **Datenbanken aktualisieren** (Profil → Datenquellen): Neue Versionen von Bundeslebensmittelschlüssel und Schweizer Nährwertdatenbank werden über GitHub verteilt – automatisch einmal pro Woche oder per „Prüfen“. Die Dateien werden vor dem Einsatz auf Vollständigkeit geprüft und bleiben danach offline nutzbar.
- Eine monatliche GitHub-Aktion übernimmt neue Versionen der Schweizer Nährwertdatenbank automatisch.

### Behoben
- **Mitteilung „Dein Vortag ist analysiert“** öffnet jetzt die App direkt mit dem Tagesfazit – auch wenn die App vorher geschlossen war.
- **Aktivitäts-Prozentsatz:** vergangene Tage zeigen den Prozentsatz, der damals galt, statt der aktuellen Einstellung.
- Das Aktivitäts-Diagramm im Verlauf zeigt immer den ganzen Zeitraum, auch am Wochenanfang.

## 1.4 – 12. Oktober 2026

### Neu
- **Mehr Lebensmittel:** die Schweizer Nährwertdatenbank (BLV) ist als zweite Offline-Datenbank dabei – 1.216 Lebensmittel, darunter rund 150 fertige Gerichte wie Burger, Kebab, Pizza, Lasagne oder Gratins.
- **Mit KI schätzen:** Restaurantgerichte ohne Datenbankeintrag oder ganze Sätze („2 Eier und ein Toast“) direkt in der Suche schätzen lassen.
- **Klügere Suche:** verzeiht Tippfehler und Mehrzahl, findet getrennte Wörter („Käsespätzle“ → „Spätzle mit Käse“) und ignoriert Füllwörter wie Mengenangaben.
- **Datenquellen einzeln abschaltbar** (Profil → Datenquellen).
- **Ziel pro Wochentag** – z. B. mehr an Trainingstagen oder am Wochenende.
- **Aktivitätskalorien aus Apple Health:** werden auf der Heute-Seite angezeigt und lassen sich per Slider zu 0–100 % aufs Kalorienziel anrechnen. Aktivität ohne Uhr kann man auch selbst eintragen.
- **Tagesübersicht:** Antippen der oberen Karte zeigt, wie sich das Tagesziel zusammensetzt, dazu Aktivität, Makros, Wasser und Score.
- **Tag teilen:** fünf Designs zum Durchwischen (Kalorien, Makros, Health Score, Woche, Story) für WhatsApp, Instagram & Co.
- **Diagramme erkunden:** im Verlauf auf ein Diagramm drücken und über die Balken wischen zeigt die Werte jedes Tages – mit Haptik, wie in Health/Fitness.
- **Kaloriendefizit** im Verlauf: Gesamtverbrauch (Grundumsatz + Aktivität aus Apple Health) minus gegessen, pro Zeitraum und pro Tag.
- **KI-Modelle getrennt wählbar:** Foto-Erkennung und Tagesanalyse können unterschiedliche Anbieter und Modelle nutzen.

### Verbessert
- **Zieländerungen gelten ab heute** – vergangene Tage behalten das Ziel, das damals galt.
- **Kalorien-Diagramm:** hinter jedem Tag zeigt eine Zielsäule das Tagesziel inklusive Aktivitätsanteil.
- **Zuletzt & Favoriten:** die große Zahl zeigt die kcal der Menge, die eingetragen wird; kcal pro 100 g stehen klein darunter.
- **Ø nach Wochentag** erscheint nur noch bei 30/90 Tagen und erklärt, was sie zeigt.
- Die Versionsnummer im Profil stimmt jetzt automatisch.

### Behoben
- Absturz bzw. absurde Werte bei den Mengen-Slidern der KI-Schätzung und Foto-Erkennung.
- Foto-Erkennung und „Tag abschließen“ funktionieren jetzt auch mit Claude.

## 1.3 – 11. Oktober 2026

### Neu
- **Vortag nachts analysieren** (Profil → Funktionen): Ab etwa 0:30 Uhr schließt die KI im Hintergrund den Vortag ab und du bekommst eine Mitteilung mit Einordnung und Health Score. iOS bestimmt den genauen Zeitpunkt (meist nachts beim Laden); verpasste Analysen werden beim nächsten Öffnen der App nachgeholt. Ein Tipp auf die Mitteilung öffnet das Tagesfazit.
- **Health Score mit und ohne KI:** Ein „+3 KI“-Abzeichen und ein heller Abschnitt im Ring zeigen, wie viel die KI-ergänzten Mikronährstoffe ausmachen. Die Detailansicht vergleicht „Eigene Daten“ mit „Mit KI-Ergänzung“, auch pro Bereich.


## 1.2 – 11. Oktober 2026

### Neu
- **Tag abschließen:** Ein Button am Ende der Tagesliste lässt die KI (derselbe Anbieter und Schlüssel wie bei der Foto-Erkennung) fehlende Mikronährstoffe für alle Einträge ergänzen – Barcode-Produkte, KI-Scans, eigene Lebensmittel und Rezept-Zutaten. Etikett- und BLS-Werte bleiben unverändert, der Health Score rechnet danach mit den vollständigen Werten.
- **Tagesfazit:** Nach dem Abschluss ordnet die KI den Tag in 1–2 Worten ein; ein Tipp darauf zeigt Stichpunkte zu dem, was gut lief, was fehlte, und Tipps für morgen. Ändert sich der Tag danach, wird das Fazit als „veraltet“ markiert und lässt sich neu bewerten.

### Verbessert
- **Mitternacht:** „Heute“ wechselt um 0 Uhr automatisch auf den neuen Tag, Widgets zeigen ab Mitternacht den leeren neuen Tag.
- **Sicherung** enthält jetzt auch die Zutaten von Mahlzeiten und die Tagesfazits.
- **KI-Schlüssel:** Eingefügte Schlüssel funktionieren zuverlässiger, auch wenn beim Kopieren versehentlich ein Leerzeichen mitkommt.

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
