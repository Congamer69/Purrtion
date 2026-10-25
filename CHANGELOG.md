# Changelog

## 3.0.1 – Anmeldung ohne Verlust des Freunde-Kontos – 25. Oktober 2026

### Behoben
- **Google-Anmeldung ersetzte das Freunde-Profil**, obwohl das Google-Konto neu war. Ursache: Ein früherer, abgebrochener Anmeldeversuch hatte auf dem Server schon ein leeres Konto für das Google-Konto angelegt. Ein solches leeres Konto (ohne Freunde-Profil und ohne Backup) wird jetzt gelöscht und das Google-Konto an dein Freunde-Konto gehängt. Nur wenn das Google-Konto wirklich schon Daten hat, fragt die App nach.
- Die Anmelde- und die Einladungsseite zeigen die Purrtion-Katze statt eines Emojis.

## 3.0 – Konto mit Google, Freunde-Server eingebaut (iPhone und Android) – 25. Oktober 2026

### Neu
- **Der Freunde-Server ist eingebaut.** Kein Server-Code, kein Verbinden, kein eigener Server: Freunde-Code teilen oder eingeben, fertig. Die Optionen „Server-Code teilen“ und „Freunde-Server trennen“ gibt es nicht mehr. (Wer Purrtion selbst baut, kann weiter ein eigenes Firebase-Projekt eintragen, siehe `backend/README.md`.)
- **Konto (Einstellungen → Konto):** Mit Google anmelden. Das Freunde-Konto wird mit dem Google-Konto verknüpft (gleiche Kennung, Freunde und Code bleiben). Auf einem neuen Gerät: mit dem gleichen Google-Konto anmelden, Freunde und Backup sind wieder da.
- **Server-Backup:** Einträge, Rezepte, eigene Lebensmittel, Gewicht und Einstellungen liegen auf dem Server (gleiches Format wie die Sicherungsdatei, auch zwischen iPhone und Android nutzbar), bis zu 10 MB. Täglich automatisch, per „Jetzt sichern“ oder „Backup laden“. Zwei Speicherplätze wechseln sich ab, ein abgebrochener Upload zerstört das letzte Backup nicht. Ein fast leeres neues Gerät überschreibt ein größeres Server-Backup nicht ohne Nachfrage.
- Die lokale Sicherung (Ordner, Datei, Passwort für das Freunde-Konto) funktioniert unverändert und ohne Google.

### Geändert
- Beim Löschen der Freunde-Daten bleibt ein mit Google verknüpftes Konto bestehen.
- Die Sicherung enthält keine Serverdaten mehr.
- Die Release-Apps (IPA, APK) werden lokal gebaut, weil die Serverkonfiguration nicht im Repository liegt.

### Behoben
- Anmeldung mit Google: Die Antwort des Servers wird toleranter ausgewertet, Fehler nennen jetzt den Grund.

## 2.6.1 – Widgets, Shop und Freunde (iPhone und Android) – 25. Oktober 2026

### Behoben
- **Widgets zeigten nur noch 2000 kcal (iPhone, SideStore):** SideStore benennt die App-Gruppe um und hängt die Team-ID an. Die App hat den neuen Namen nicht gefunden, deshalb teilten App und Widget keine Daten. Die App sucht den Namen jetzt in der Signatur der App und nimmt den, den iOS freigibt. Das gilt auch für die Widgets auf dem Sperrbildschirm.
- **Shop und Serie-Seite ruckelten (iPhone):** Pixel-Katzen werden jetzt als fertige Bilder gezeichnet statt Pixel für Pixel in jedem Bild, der Shop hat eigenen Zustand (Kaufen und Kategorie wechseln zeichnet nicht mehr die ganze Seite neu) und der Kategoriewechsel läuft ohne Animation.

### Geändert
- **Punkte umgekehrt:** 5 Punkte für jeden eingetragenen Tag, 10 mehr für Tage nahe am Ziel. Meilensteine geben weiter Boni.
- **Zielgewicht** hat jetzt ein Zahlenfeld statt Regler oder Tasten (iPhone und Android).

### Neu
- **Freunde sehen deine Outfits:** Hut, Brille, Schal und Fellfarbe aus dem Shop erscheinen bei deinen Freunden. Das ist immer aktiv und hängt nicht am Schalter für den Shop. Ältere App-Versionen ignorieren die Daten und zeigen die Katze ohne Kleidung.

## 2.6 – Extras, Shop, App-Symbole (iPhone und Android) – 25. Oktober 2026

### Neu (alles einzeln ein- und ausschaltbar unter Profil → Funktionen → Extras)
- **Wochenbudget:** Ein Tag über oder unter dem Ziel verteilt sich auf die übrigen Tage der Woche (Montag bis Sonntag), höchstens um den eingestellten Anteil pro Tag (5 bis 30 %, Standard 15 %). Auf „Heute“ steht, was dazukommt oder abgezogen wird. Vergangene Tage behalten ihr damaliges Ziel.
- **Vorschläge zur Uhrzeit:** Beim Hinzufügen steht oben „Um diese Zeit“: was du in den letzten 60 Tagen um diese Uhrzeit (±90 Minuten) am häufigsten gegessen hast. Ein Tipp trägt es ein.
- **Mehrfach-Scan:** Nach dem Barcode gibt es neben „Hinzufügen“ die Taste „Weiteres scannen“. Sie trägt ein und geht zurück zur Kamera.
- **Gewichts-Prognose:** Mit Zielgewicht zeigt das Gewichtsdiagramm eine gestrichelte Linie und ein Datum mit Spanne („voraussichtlich 12. Dezember, 28. Nov bis 3. Jan“). Sie nutzt den robusten Trend der letzten sechs Wochen, braucht drei Wägungen über mindestens zehn Tage und sagt es, wenn der Trend vom Ziel wegzeigt oder flach ist.
- **Sanfte Erinnerung:** Eine Mitteilung der Katze zu deiner Uhrzeit, nur wenn heute noch nichts eingetragen ist. Auf Android prüft sie das beim Auslösen, auf dem iPhone wird die heutige gestrichen, sobald du etwas einträgst.
- **Shop und Outfits:** In der Serie gibt es Punkte (10 pro eingetragenem Tag, +5 für Tage nahe am Ziel, Boni für Meilensteine). Dafür gibt es fünf Fellfarben, fünf Hüte, zwei Brillen, fünf Schals und einen Extra-Freeze, alles in Pixeln auf der Katze. Gekaufte Fellfarben erscheinen unter Darstellung.
- **App-Symbole (iPhone):** Acht Symbole (Standard, Mitternacht, Minze, Sakura, Retro, Dämmerung, Noir, Blaubeere) unter Profil → Darstellung, jeweils hell, dunkel und eingefärbt.
- **Widget „Makros“ (iPhone):** Quadratisch, mit übrigen kcal, gegessen von Ziel und Protein, Kohlenhydraten und Fett in Gramm.

### Verbessert
- Farbrad: Das Farbrad öffnet sich jetzt zuverlässig als eigenes Fenster (vorher nur manchmal).
- Die Sicherung enthält die neuen Einstellungen (Extras, Zielgewicht, gekaufte Dinge).

## 2.5 – Eigene Farbe, mehr Widgets (iPhone und Android) – 25. Oktober 2026

### Neu
- **Eigene Akzentfarbe:** Der letzte Farbkreis (vorher Graphit) öffnet ein Farbrad. Auf dem iPhone ist es das System-Farbrad, auf Android ein eigenes mit Helligkeitsregler. Zu dunkle Farben werden für Text im Dunkelmodus automatisch aufgehellt. Die Farbe steht in der Sicherung und wandert zwischen iPhone und Android mit. Das alte Graphit wird zur eigenen Farbe mit demselben Grau.
- **Widget „Heute“ mit Auswahl (iPhone):** Gedrückt halten → „Widget bearbeiten“. Quadratisch: Katze mit Ring oder Mehr Infos (übrige kcal, gegessen, Fortschritt, Protein, Kohlenhydrate, Fett, Wasser, Score). Breit: Makros und Wasser oder die Woche (sieben Balken in Zielfarben). Die Widgets nutzen deine Akzentfarbe.
- **Widget „Schnell eintragen“ (iPhone):** Tasten für Suchen, Barcode, Foto und Schnell-Eintrag öffnen Purrtion direkt an der richtigen Stelle. Das breite Widget zeigt dazu die übrigen kcal und trägt Wasser mit einem Tipp ein, ohne die App zu öffnen. Die App übernimmt es beim nächsten Öffnen.
- **Darstellung:** „Deine Katze & Look“ steht jetzt über „Stil“ (iPhone und Android).

### Behoben
- **Widget nach Mitternacht:** Es zeigte als offene Kalorien das Ziel plus die aktiven Kalorien des Vortags, bis die App geöffnet wurde. Jetzt gilt ab Mitternacht das Ziel des neuen Tages ohne den Bonus von gestern.
- **„Bis +5 %“ ist immer orange (Android):** Die Farbe folgte bisher der Akzentfarbe, wie auf dem iPhone ist sie jetzt fest.
- **Tab-Leiste:** Im Video-Test bleibt die Leiste mit ausgeblendeter Freunde-Seite beim Wechsel zwischen den Seiten gleich breit.
- **Sicherung:** Die iPhone-Sicherung enthält jetzt auch die Darstellungs-Einstellungen (Farbe, Ecken, Karten, Hintergrund, Schrift).

## 2.4.4 – Ziele bei der Wiederherstellung, Health-Anfrage, Tab-Leiste (iPhone, Sicherung auch Android) – 25. Oktober 2026

### Behoben
- **Ziele nach der Wiederherstellung:** Der Verlauf deiner Kalorienziele ging beim Wiederherstellen verloren, alle vergangenen Tage zeigten wieder 2000 kcal. Die App hielt den alten Wert im Speicher und schrieb ihn kurz nach dem Wiederherstellen zurück. Jetzt bleibt der wiederhergestellte Verlauf erhalten.
- **Aktivität bei „Zugriff auf Health neu anfragen“:** Der Knopf fragt Gewicht, Ernährung und Aktivitätskalorien jetzt in einer einzigen Anfrage, sodass iOS alle drei zusammen anzeigt. Beim Start fragt die App ebenfalls nach, wenn für eine eingeschaltete Funktion (auch Aktivität) noch keine Antwort vorliegt.
- **Tab-Leiste mit drei Tabs:** Ist die Freunde-Seite ausgeblendet, sprang die Leiste zwischen breit (Heute) und schmal (andere Seiten). Die Schnell-Leiste bleibt jetzt auf allen Seiten und die Leiste ändert ihre Breite nicht mehr.

### Neu
- **Schutz der Sicherung:** Zeigst du einer frisch installierten App den alten Sicherungsordner, überschrieb sie die gute Sicherung mit fast leeren Daten. Enthält die neue Sicherung weniger als die Hälfte der Einträge der vorhandenen, bleibt die alte als „Purrtion-Backup-Vorher.json“ daneben liegen (iPhone und Android).

## 2.4.3 – Apple Health mit SideStore repariert (iPhone) – 25. Oktober 2026

### Behoben
- **Berechtigungen im IPA:** Das IPA war ganz ohne Berechtigungen gebaut (bei Apple Health „Missing com.apple.developer.healthkit entitlement“), und SideStore übernimmt nur, was schon in der App steht. Jetzt tragen App und Widget ihre Berechtigungen (HealthKit, App-Gruppe) schon im IPA, SideStore ersetzt nur die Signatur. Das reicht allein nicht: SideStore fragt für kostenlose Konten HealthKit nie bei Apple an, deshalb fehlt die Berechtigung im Profil trotzdem. Die Einbettung ist nötig, falls SideStore HealthKit anfragen darf (siehe README).

### Neu
- **Aktivitätskalorien unter Apple Health:** Ob Purrtion deine aktiven Kalorien liest, stellst du jetzt unter Profil → Apple Health ein. Unter Ziele → Kalorien & Makros legst du nur noch fest, wie viel davon aufs Ziel angerechnet wird.
- **„Zugriff auf Health neu anfragen“:** Knopf unter Profil → Apple Health. Er fragt Gewicht, Ernährung und Aktivität neu an und nennt bei einem Fehler den Grund.

## 2.4.2 – Update-Knopf repariert (iPhone) – 25. Oktober 2026

### Behoben
- **„Aktualisieren“ in der App** brach in SideStore mit „bundle ID does not match“ ab. Der Knopf heißt jetzt „SideStore öffnen“ und zeigt die Schritte: in SideStore unter „Meine Apps“ nach unten ziehen und bei Purrtion „Update“ tippen. Das Update läuft dann über die Quelle.

## 2.4.1 – Apple Health nach SideStore-Refresh (iPhone) – 25. Oktober 2026

### Verbessert
- **Health-Freigaben:** Hat iOS nach dem Neu-Signieren (SideStore „Refresh“) die Antworten für Apple Health vergessen, fragt Purrtion beim Start neu nach. Sind die Rechte noch gesetzt, erscheint nichts.
- **Fehler sichtbar:** Schlägt das Schreiben in Apple Health fehl, steht der Fehler unter Profil → Apple Health. Ein fehlgeschlagenes Schreiben gilt nicht mehr als erledigt und wird beim nächsten Mal wiederholt.

## 2.4 – Freunde-Konto in der Sicherung (iPhone und Android) – 24. Oktober 2026

### Neu
- **Freunde-Konto mitsichern:** Unter Daten & Backup lässt sich dein Freunde-Konto verschlüsselt in die Sicherung aufnehmen. Beim Wiederherstellen (auch nach Neuinstallation, Wechsel zu SideStore oder zwischen iPhone und Android) kommen Profil, Freunde und Server-Verbindung zurück.
- **So ist es geschützt:** Du legst ein Passwort fest (mindestens 8 Zeichen). Daraus wird per PBKDF2 ein Schlüssel abgeleitet, die Anmeldung wird mit AES-256-GCM verschlüsselt. Das Passwort bleibt nur auf dem Gerät (Schlüsselbund bzw. Android Keystore) und steht nicht in der Sicherung. Ein falsches Passwort verändert nichts. Ohne das Passwort ist die Anmeldung in der Datei nicht lesbar und nicht wiederherstellbar. Ausgeschaltet wird sie aus der Sicherung wieder entfernt.
- **Besser gesichert:** Name für Freunde, Ein/Aus der Freunde-Seite, Gewichtstrend teilen und die gewählte Kennzahl stehen jetzt auch in der iPhone-Sicherung.

### Verbessert
- Die README beginnt jetzt mit der Installation für iPhone und Android.

## 2.3 – Updates per SideStore (iPhone) – 24. Oktober 2026

### Neu
- **App-Update:** Purrtion prüft beim Start (höchstens alle 6 Stunden) und unter Profil → App-Update, ob eine neuere Version in der SideStore-Quelle steht, zeigt Hinweise und öffnet SideStore zum Aktualisieren. „Später“ blendet die Meldung drei Tage aus. Ohne Verbindung passiert nichts.
- **SideStore-Quelle und Release-Workflow:** `distribution/sidestore-source.json`, `tools/build-ipa.sh`, GitHub-Workflow „iPhone-Release (SideStore)“. Das IPA enthält keine Freunde-Server-Daten. Einrichtung: [distribution/README.md](distribution/README.md).

### Verbessert
- Das Widget findet seine App-Gruppe auch, wenn SideStore sie umbenennt.

## 2.2 – Gemüse zählt auch bei KI und Scans (iPhone und Android) – 24. Oktober 2026

### Neu
- **KI schätzt Obst und Gemüse:** Bei „Tag abschließen“ schätzt die KI für alle Lebensmittel, die die Datenbanken nicht einordnen können (gescannte Produkte, eigene Lebensmittel, Restaurant- und Schnell-Einträge), welcher Anteil des Gewichts Obst, Gemüse, Pilze oder Hülsenfrüchte ist. Kartoffeln, Pommes, Säfte, Trockenobst und Nüsse zählen nicht.
- **Auch bei Foto und Beschreibung:** Die Fotoerkennung und die Text-Schätzung geben den Obst- und Gemüseanteil jedes Bestandteils gleich mit an (Gemini, Claude, OpenAI und Apple-KI).
- **Aussagekräftiger Health Score:** Der Punkt „Obst & Gemüse“ nutzt diese Schätzungen. Der Vorher-Score bei „Tag abschließen“ rechnet ohne KI, der Nachher-Score mit.
- **Freunde-Vergleich:** „Obst & Gemüse“ nutzt dieselbe Rechnung.

### Verbessert
- **Rezepte und KI-Gerichte** werden pro Zutat gezählt. Das Gemüse in einem Rezept aus Datenbank-Zutaten zählt jetzt mit.

## 2.1.1 – Absturzbericht und abgesicherter Modus (Android) – 24. Oktober 2026

### Neu
- **Absturzbericht:** Stürzt die App ab, zeigt ein eigener, einfacher Bildschirm den Fehler, die App-Version, das Gerät und die letzten Schritte der App. Der Bericht lässt sich mit einem Tipp kopieren oder teilen. Der Bildschirm läuft in einem eigenen Prozess und funktioniert auch dann, wenn Datenbank, Einstellungen oder Design die Ursache sind. Im Bericht stehen keine Einträge, Schlüssel oder Namen.
- **Abgesicherter Modus:** Vom Absturzbildschirm aus startet die App einmal mit Standardlook, ohne Hintergrundaufgaben und ohne Freunde-Seite. Beim nächsten Start ist wieder alles normal.
- **Diagnose in den Einstellungen:** Einstellungen → Diagnose zeigt denselben Bericht jederzeit, dazu den letzten Absturz und Fehler, die die App abgefangen hat.

### Verbessert
- **Robuster Start:** Hintergrundaufgaben (Widget, Backup, Health Connect, Updates, Freunde) laufen einzeln abgesichert. Schlägt eine fehl, laufen die anderen weiter und die App bleibt offen. Fehler werden im Bericht festgehalten.
- **Sicherere Schrift:** Die runde Systemschrift wird nur genutzt, wenn das Gerät sie wirklich hat, sonst die Standardschrift.
- **Beschädigte Einstellungen:** Falsch gespeicherte Werte stürzen die App nicht mehr ab, sondern fallen auf den Standard zurück. Das gilt auch für Design, Startseite, Serie, Wochenleiste und Hundesprites.
- **Haptik:** Ein Gerät ohne bestimmtes Vibrationsmuster führt nicht mehr zu einem Fehler.

## 2.1 – Redesign (iPhone und Android) – 23. Oktober 2026

### Neu
- **Android im neuen Look:** Die Android-App folgt dem neuen 2.1-Design: Darstellung zum Anpassen (Akzent, Ecken, Karten, Hintergrund, Schrift) mit Live-Vorschau, Wochenleiste auf „Heute“, Serie mit Streak-Freezes und Meilensteinen, Rückgängig nach dem Löschen, anpassbarer Verlauf, gruppierte Einstellungen, neu geordnete Freunde, neuer Startbildschirm (auch dunkel) und der geheime Hund.
- **Besser lesbar im hellen Modus:** Texte in Akzent-, Wasser-, Makro- und Zielfarben sind auf hellem Hintergrund jetzt dunkler, die Zweitfarbe der Texte kräftiger. „Schwarz“ heißt im hellen Modus „Weiß“.
- **Neue Navigation:** Heute, Verlauf, Profil (und Freunde, wenn aktiv) in der nativen Leiste.
- **Eintragen mit einem Tipp:** Suchen, Barcode, Foto und Schnell sitzen als Zusatzleiste direkt über der Tab-Leiste auf „Heute“ (iOS-Bottom-Accessory).
- **Neues Suchfenster:** Barcode, Foto und Schnell-Eintrag sind auch hier, dazu „Was passt noch?“ und Zuletzt/Favoriten/Meine.
- **Heute neu aufgebaut:** Wochenleiste, die du zwei Jahre zurück wischen kannst, mit gefüllter Akzent-Kapsel für den gewählten Tag und Statuspunkt (Ziel, knapp drüber, drüber, Freeze) statt Pfeilen, Serie im Kopf, eine große Karte mit Kalorienring, Katze und Makros, Health Score und Tagesfazit wie gewohnt, schmale Wasser-Zeile, Mahlzeiten mit Uhrzeit weiter oben. Leerer Tag mit vier Startoptionen.
- **Verlauf:** Kalorien-Diagramm zuerst, dann Serie, echter Verbrauch, Zielübersicht, Score und Gewicht. Seltener genutzte Auswertungen stehen unter „Weitere Auswertungen“. Zeiträume: Woche, Monat, 3 Monate.
- **Profil:** Einstellungen nach Aufgaben gruppiert (Darstellung, Funktionen, Apple Health, Freunde, Daten & Backup, Datenquellen & KI).
- **Einrichtung in vier Schritten:** Ziel, Eckdaten per Wheel-Picker, Aktivität, Tagesziel mit Apple-Health-Option.
- **Serie mit Streak-Freeze:** Die Serie sitzt oben rechts auf „Heute“ (grau, bis du heute etwas einträgst). Tippen öffnet die Serien-Ansicht mit Rekord, Freezes und den letzten fünf Wochen. Fehlt ein Tag, rettet ein Freeze die Serie automatisch. Alle 7 Tage in Folge gibt es einen neuen, maximal 2. Beim ersten Eintrag des Tages hüpft die Serie wie ein Gummiball (zusammendrücken, springen, aufsetzen), die Flamme schwillt an und wackelt, die Kapsel blitzt einmal orange auf. Es dauert unter einer Sekunde und hält dich nicht auf. Hat gestern ein Freeze die Serie gerettet und heute ist noch nichts eingetragen, wird aus der Flamme eine blaue Schneeflocke, und der Tag steht blau in der Wochenleiste.
- **Mehr Platz auf „Heute“:** Die Wochenleiste ist nicht mehr angeheftet und scrollt mit. Beim Runterscrollen schrumpft die Tab-Leiste und die Zusatzleiste rückt als „Suchen“-Button daneben (ein Tipp öffnet direkt die Suche). Beim Hochscrollen kommt alles zurück. Das macht iOS selbst.
- **Neuer Start:** Orangefarbener Startbildschirm in der Farbe des App-Icons. Eine cremefarbene Scheibe poppt auf, die Katze fällt hinein, ein Ring zeichnet sich darum, und die Buchstaben springen nacheinander ein. Danach hebt sich das Logo weg, das Orange blendet aus und die App setzt sich sanft darunter ein.
- **Darstellung zum Anpassen:** Profil → Darstellung hat jetzt eine Live-Vorschau, deinen Namen (Begrüßung auf „Heute“), sechs Akzentfarben, Ecken (eckig, rund, extra rund), Kartenstil (Schatten, flach, Rand), Hintergrund (warm, neutral, schwarz) und Schrift (rund, Standard, Serif, Mono). Mit „Auf Standard zurücksetzen“.
- **Lesbarere Zusatzleiste:** Beschriftung in Textfarbe, Akzent nur auf den Symbolen.
- **Einheitliche Bewegung:** Alle Animationen nutzen jetzt fünf gemeinsame Federn (schnell, weich, verspielt, Füllen, Drücken) statt vieler einzelner Werte. Wasserglas, Katze, Ringe, Balken, Listen und Auswahl fühlen sich dadurch gleich an.
- **Einheitliche Typografie und Abstände:** vier Schriftgrößen, zwei Schriftstärken, weiche getönte Schatten.
- **Serien-Ansicht neu:** leuchtende Flamme, Fortschritt bis zum nächsten Freeze, Kacheln für Rekord, aktive Tage und genutzte Freezes, Meilensteine (3 bis 365 Tage) und die letzten fünf Wochen als Kette, in der aufeinanderfolgende Tage verbunden sind.
- **Rückgängig statt Schreck:** Nach dem Löschen eines Eintrags, mehrerer Einträge oder einer Zutat erscheint zehn Sekunden lang ein „zurück“-Button neben dem „…“-Menü auf „Heute“.
- **Dunkler Startbildschirm:** folgt dem Akzent und der Hintergrund-Einstellung (auch komplett schwarz).
- **Verlauf anpassen:** Karten per Ziehen umsortieren und ein- oder ausblenden. Seltenere Auswertungen sind standardmäßig ausgeblendet.
- **Freunde neu geordnet:** ein Menü oben rechts (hinzufügen, einladen, verwalten), kompaktes Profil mit Code zum Kopieren, Wochenvergleich mit Punkten.
- **Daten und KI getrennt:** „Datenquellen“ und „KI-Modelle“ sind eigene Einträge im Profil.
- **Mehr Anpassung:** Startseite (Heute oder Verlauf) und haptisches Feedback lassen sich einstellen.
- **Geheimnis:** Fünfmal schnell auf das Logo im Profil tippen. Ein Hund zieht ein, mit allen Stimmungen der Katze. Die Freischaltung bleibt, zurück zu den Katzen geht in der Darstellung, den Hund gibt es per erneutem Fünffachtippen.

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
