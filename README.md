<p align="center"><img src="docs/icon.png" width="128" alt="Purrtion App-Icon"></p>

# Purrtion 🐾

Kalorientracker für iPhone (SwiftUI, SwiftData, iOS 27+, optimiert für iPhone 17/18 Pro Max), komplett im Pixel-Katzen-Look.
Keine laufenden Kosten, kein Account, alle Daten bleiben auf dem Gerät.

**Version 1.5** – siehe [CHANGELOG.md](CHANGELOG.md).

## Highlights
- Eine einfache Liste pro Tag statt Frühstück/Mittag/Abend; Rezepte und Foto-Scans bleiben ein Eintrag mit ausklappbaren Zutaten
- Schnelle Eingabe: Suche, Barcode, Foto vom Teller, Schnell-Eintrag, Favoriten, „Nochmal“ per Wischen
- Makro- und Mikronährstoffe aus Bundeslebensmittelschlüssel und Schweizer Nährwertdatenbank (offline), echte Portionsgrößen
- Fehlertolerante Suche; was keine Datenbank kennt, schätzt die KI – auch ganze Sätze wie „2 Eier und ein Toast“
- Ziel pro Wochentag, Aktivitätskalorien aus Apple Health (optional aufs Ziel angerechnet), Zieländerungen gelten ab heute
- Verlauf mit Zielfarben (grün / orange bis +5 % / rot), Kaloriendefizit und Diagrammen zum Gedrückthalten und Durchwischen
- Tagesübersicht mit fünf Share-Designs für WhatsApp, Instagram & Co.
- „Tag abschließen“: KI ergänzt fehlende Mikronährstoffe und gibt ein kurzes Tagesfazit – auf Wunsch automatisch jede Nacht für den Vortag
- **Echter Verbrauch:** aus Essen und Gewichtstrend gemessener Tagesverbrauch, aufgeteilt in Grundumsatz, Verdauung und Bewegung – inklusive Abgleich mit Apple Health
- **Was passt noch?** schlägt Favoriten und Rezepte vor, die zu den restlichen Kalorien und Makros passen
- Promille-Schätzung für eingetragene Getränke (Körperwasser nach Watson, Verlauf und „nüchtern ab“)
- Health Score (mit Abzug für Alkohol), Wasser, Gewicht und Ernährung in Apple Health, Widgets, Backup und CSV-Export
- Hell- und Dunkelmodus, Pixel-Katze mit vielen Stimmungen – gähnend, hungrig, beschwipst, stolz, vollgefressen …

## Screenshots

<table>
  <tr>
    <td align="center" width="25%"><img src="docs/screenshots/today.png" width="190" alt="Heute"><br><sub><b>Heute</b></sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/meal.png" width="190" alt="Mahlzeiten"><br><sub><b>Mahlzeiten</b></sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/search.png" width="190" alt="Suche"><br><sub><b>Suche</b></sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/overview.png" width="190" alt="Tagesübersicht"><br><sub><b>Tagesübersicht</b></sub></td>
  </tr>
  <tr>
    <td align="center" width="25%"><img src="docs/screenshots/history.png" width="190" alt="Verlauf"><br><sub><b>Verlauf</b></sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/share.png" width="190" alt="Teilen"><br><sub><b>Teilen</b></sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/score.png" width="190" alt="Health Score"><br><sub><b>Health Score</b></sub></td>
    <td align="center" width="25%"><img src="docs/screenshots/widget.png" width="190" alt="Widget"><br><sub><b>Widget</b></sub></td>
  </tr>
</table>

## Voraussetzungen
Xcode 27 und iOS 27 (Simulator oder iPhone).

## Starten
- In Xcode: `Purrtion.xcodeproj` öffnen → Simulator wählen → ▶︎
- Oder per Terminal (baut und startet im laufenden Simulator): `./run.sh`

> Das Projekt liegt in einem iCloud-synchronisierten Ordner. Build-Produkte im Projektordner
> brechen dort die Code-Signatur ("resource fork … not allowed") – `run.sh` legt sie deshalb in `$TMPDIR` ab.

## Datenquellen (alles kostenlos, in Profil → Datenquellen einzeln abschaltbar)
| Quelle | Wofür |
|---|---|
| **Schweizer Nährwertdatenbank** (BLV, V 7.1) | ~1.200 Lebensmittel, darunter ~150 fertige Gerichte (Burger, Kebab, Pizza, Gratins …), offline in `Purrtion/Resources/swiss.json` |
| KI-Schätzung | alles ohne Datenbankeintrag oder ganze Sätze („2 Eier und ein Toast“), nutzt den KI-Anbieter der Foto-Erkennung |
| **Bundeslebensmittelschlüssel 4.0** (Max Rubner-Institut, CC BY 4.0) | ~7.100 Lebensmittel mit bis zu 138 Nährstoffen, offline in `Purrtion/Resources/bls.json` |
| Purrtion-Beliebtliste (`PopularFoods.swift`) | ~100 Alltagslebensmittel mit Namen & echten Portionsgrößen, auf BLS-Einträge gemappt |
| Open Food Facts | Barcodes & Markenprodukte, deutsche Produkte bevorzugt, unplausible Werte markiert |

BLS aktualisieren: Excel von https://blsdb.de laden und
`python tools/convert_bls.py BLS_4_0_Daten_2025_DE.xlsx Purrtion/Resources/bls.json` (braucht `openpyxl`).
Schweizer Datenbank aktualisieren: Excel von https://naehrwertdaten.ch/de/downloads/ laden und
`python tools/convert_swiss.py Schweizer_Nahrwertdatenbank.xlsx Purrtion/Resources/swiss.json`.

Die App lädt neue Datenbank-Versionen selbst nach (Profil → Datenquellen → „Datenbanken aktualisieren“, automatisch wöchentlich): `data/manifest.json` nennt Version und Revision jeder Datei, `python tools/update_manifest.py` aktualisiert es nach einer neuen Konvertierung. Die GitHub-Aktion `.github/workflows/update-databases.yml` übernimmt neue Versionen der Schweizer Datenbank monatlich automatisch.

Die Suche verzeiht Tippfehler, Mehrzahl und getrennte Wörter („Käsespätzle“ findet „Spätzle mit Käse“).

## KI (Profil → KI-Modelle)
Foto-Erkennung und Tagesanalyse („Tag abschließen“) können unterschiedliche Anbieter und Modelle nutzen – z. B. Claude Opus für Fotos und das günstigere Sonnet oder Gemini für die Tagesanalyse. Standardmäßig folgt die Tagesanalyse der Foto-Erkennung.

| Anbieter | Kosten |
|---|---|
| Apple Intelligence (Standard) | kostenlos, auf dem iPhone; Fallback: Apples Vision-Bilderkennung |
| Google Gemini | kostenloses Kontingent mit eigenem Schlüssel |
| Claude (Anthropic) | ein paar Cent pro Foto, eigener Schlüssel |
| OpenAI | ca. 1 Cent pro Foto, eigener Schlüssel |

Die KI zerlegt das Gericht in seine Bestandteile (inkl. Soßen, Öl, Beilagen) und schätzt für jeden die Menge
sowie Kalorien, Makros und – wo sinnvoll – Mikronährstoffe selbst. So bekommt z. B. „Schnitzel paniert“ eine
eigene Schätzung statt eines nur ungefähr passenden Datenbankeintrags. Vor dem Eintragen lässt sich jeder
Bestandteil anpassen, abwählen oder durch ein Lebensmittel aus der Datenbank ersetzen; die Mahlzeit landet
als ein Eintrag mit ausklappbaren Zutaten unter „Gegessen“.
Nur der Offline-Fallback (Apples Vision-Bilderkennung) erkennt lediglich das Lebensmittel und nimmt die Nährwerte aus dem BLS.
Schlüssel liegen in der Keychain und gelten pro Anbieter für beide Aufgaben; das Modell ist pro Aufgabe wählbar (Vorschläge im Menü oder eigene Modell-ID).

## Weitere Funktionen
- **Health Score (0–100):** acht Bereiche nach WHO, DGE, GBD 2017 (Lancet 2019) und EU-NRV – `Services/HealthScore.swift`
- **Eigene Lebensmittel & Rezepte** (Meal Prep mit Portionen) – `Models/CustomFood.swift`, `Views/CustomFoodViews.swift`
- **Sicherung:** JSON-Backup etwa täglich in einen gewählten (iCloud-Drive-)Ordner + Wiederherstellen – `Services/Backup.swift`
- **CSV-Export** (Essen, Tage, Gewicht; Semikolon + deutsches Komma für Excel)
- **Apple Health:** Gewicht in beide Richtungen – `Services/HealthSync.swift`; Aktivitäts- und Ruheenergie lesen, Aktivität per Slider (0–100 %) aufs Ziel anrechnen, eigene Aktivität ergänzen – `Services/ActivityStore.swift`
- **Kaloriendefizit:** Gesamtverbrauch (Grundumsatz + Aktivität) minus gegessen, für abgeschlossene Tage; ohne Health-Daten wird der Grundumsatz nach Mifflin-St Jeor geschätzt
- **Tagesübersicht & Teilen:** obere Karte auf „Heute“ antippen – Zielaufbau, Aktivität, Makros und fünf Share-Bilder (Kalorien, Makros, Health Score, Woche, Story) – `Views/DayOverviewViews.swift`
- **Diagramme erkunden:** gedrückt halten und wischen wie in Health/Fitness, mit Haptik – `Views/ChartScrub.swift`
- **Ziele:** eigenes Kalorienziel pro Wochentag; Zieländerungen gelten ab heute, vergangene Tage behalten ihr damaliges Ziel – `Models/Goals.swift`
- **Widgets:** Homescreen (quadratisch, breit) und Sperrbildschirm – Ziel `PurrtionWidget`, Daten über App Group `group.com.const.purrtion`

## Auf dem echten iPhone installieren
In Xcode beim Ziel **Purrtion** und **PurrtionWidget** unter „Signing & Capabilities“ dein Team auswählen.
App Groups und HealthKit funktionieren auch mit einem kostenlosen Apple-Account.

## Struktur
- `Shared/` – Theme, Pixel-Sprites und Widget-Datenformat (von App und Widget genutzt)
- `Purrtion/Pixel` – Animations-Views
- `Purrtion/Models` – Nährstoffe, Lebensmittel, SwiftData-Modelle, Ziele
- `Purrtion/Services` – BLS-Datenbank, Beliebtliste, Open Food Facts, Foto-Analyse (Apple/Gemini/Claude/OpenAI), Keychain
- `Purrtion/Views` – Heute, Suche, Detail, Barcode, Foto, Schnell-Eintrag, Verlauf, Profil
- `tools/` – `make_icon.py` (App-Icon), `preview_sprites.py` (Sprite-Vorschau), `convert_bls.py` (BLS-Import)

## Lizenz & Hinweise
Der Code steht unter der [MIT-Lizenz](LICENSE): frei nutzbar, veränderbar und weitergebbar, ohne Gewähr und ohne Haftung. Die Datenquellen haben eigene Lizenzen, siehe [NOTICE](NOTICE).

Purrtion ist ein privates Hobbyprojekt und wurde mit Unterstützung von KI (Claude Code) entwickelt.
Nährwerte, Foto-Schätzungen und der Health Score sind Richtwerte und ersetzen keine ärztliche oder ernährungsfachliche Beratung.

### Lizenzen der Daten
Bundeslebensmittelschlüssel 4.0 © Max Rubner-Institut, lizenziert unter [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Schweizer Nährwertdatenbank V 7.1, Bundesamt für Lebensmittelsicherheit und Veterinärwesen BLV, [naehrwertdaten.ch](https://naehrwertdaten.ch) – frei nutzbar mit Quellenangabe.
Produktdaten von [Open Food Facts](https://world.openfoodfacts.org) (ODbL), werden zur Laufzeit abgefragt.
