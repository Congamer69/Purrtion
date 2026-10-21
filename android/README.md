# Purrtion für Android 🐾

Native Android-Version von Purrtion: Kotlin, Jetpack Compose und Material 3, ab Android 9 (API 28).
Gleicher Funktionsumfang und gleicher Pixel-Katzen-Look wie die iPhone-App. Beide Apps teilen Datenbanken, Versionsnummer und Sicherungsformat.

## Voraussetzungen
- JDK 21 (z. B. `brew install openjdk@21`)
- Android SDK mit Plattform 35 und Build-Tools (Android Studio oder `brew install --cask android-commandlinetools`)
- Ein Emulator oder ein Android-Handy mit USB-Debugging

## Starten
```bash
cd android
./run.sh
```
`run.sh` baut die Debug-Version, installiert sie auf dem laufenden Emulator bzw. dem angeschlossenen Handy und startet sie.
Alternativ den Ordner `android/` in Android Studio öffnen und ▶︎ drücken.

Release-APK (mit R8 verkleinert, ca. 27 MB):
```bash
./build-apk.sh
```
Die Datei landet in `android/dist/Purrtion-<Version>.apk`. Sie enthält keine Daten des Freunde-Servers und kann deshalb öffentlich an den GitHub-Release. `./build-apk.sh --private` baut eine Version mit eingebautem Server aus `Firebase.plist`.

Signiert wird mit dem Debug-Schlüssel des Macs (`~/.android/debug.keystore`). **Alle APKs müssen mit demselben Schlüssel signiert sein**, sonst lässt Android sie nicht als Update über die alte Version installieren, und die Daten wären weg. Den Schlüssel also sichern.

**App-Update in der App:** Einstellungen → App-Update fragt den neuesten GitHub-Release ab und nimmt die erste `.apk` daran. Vor dem Installieren legt die App eine komplette Sicherung an (`files/update-backups`, die letzten drei, plus Sicherungsordner falls eingerichtet) und prüft die Datei: gleiche App, höhere `versionCode`, gleiche Signatur. Dann übernimmt der Android-Installer, die App-Daten bleiben dabei erhalten.
Gebaut wird nur für `arm64-v8a`, das deckt praktisch alle Handys ab Android 9 ab.

> Das Projekt liegt in einem iCloud-synchronisierten Ordner. Alle Build-Ausgaben landen deshalb in `$TMPDIR/purrtion-android-build`.

Nur im Debug-Build: `adb shell am start -n de.purrtion.app/.MainActivity --ez seedDemo true` füllt die letzten Wochen mit Beispieldaten (Einträge, Wasser, Gewicht), praktisch zum Testen von Verlauf und echtem Verbrauch.

## Was von der iPhone-App übernommen wird
- **Datenbanken:** `bls.json` und `swiss.json` werden beim Bauen aus `../Purrtion/Resources` kopiert. Updates kommen wie auf iOS über das Manifest auf GitHub.
- **Version:** `versionName` und `versionCode` stammen aus `MARKETING_VERSION` und `CURRENT_PROJECT_VERSION` des Xcode-Projekts.
- **Freunde:** Der Server wird in der App verbunden (Einstellungen → Freunde → Server-Code einfügen), siehe [backend/README.md](../backend/README.md#server-code). Nur `--private`-Builds lesen ihn aus `../Purrtion/Resources/Firebase.plist`. iPhone- und Android-Nutzer können sich gegenseitig hinzufügen.
- **Sicherung:** Die Datei `Purrtion-Backup.json` ist zwischen iPhone und Android austauschbar (Einträge, Rezepte, eigene Lebensmittel, Gewicht, Einstellungen).

## Android-Entsprechungen
| iPhone | Android |
|---|---|
| Apple Health (Gewicht, Aktivität, Ernährung) | Health Connect |
| Apple Intelligence / Vision | ML Kit Bilderkennung (offline) |
| Keychain | EncryptedSharedPreferences |
| Widget | Glance-Widget „Heute“ |
| Hintergrund-Analyse (BGTask) | WorkManager |
| iCloud-Ordner für Sicherungen | beliebiger Ordner (z. B. Google Drive) |

## Struktur (`app/src/main/java/de/purrtion/app`)
- `model/` – Nährstoffe, Lebensmittel, Formatierung
- `data/` – Room-Datenbank, Einstellungen, Speichern und Löschen
- `domain/` – Ziele, Suche, Datenbanken, Open Food Facts, KI, Health Score, echter Verbrauch, Promille, Health Connect, Sicherung, Freunde (Firebase per REST)
- `ui/` – Theme, Navigation, Bausteine, Pixel-Sprites (`pixel/Sprites.kt` wird mit `tools/export_sprites_kotlin.py` aus `Shared/PixelSprites.swift` erzeugt)
- `ui/screens/` – Heute, Suche, Detail, Barcode und Foto, Schnell-Eintrag, Kalender, Tagesübersicht, Verlauf, Freunde, Einstellungen
- `widget/` – Startbildschirm-Widget
