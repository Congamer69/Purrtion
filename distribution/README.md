# Purrtion auf dem iPhone mit SideStore aktualisieren

Kostenlos und privat: Das IPA liegt bei GitHub Releases, SideStore auf dem iPhone findet neue Versionen und aktualisiert Purrtion.
Die App selbst installiert nichts. Sie meldet nur „Update verfügbar“ und öffnet SideStore (iOS erlaubt keine Selbst-Updates).

## Quelle für SideStore

```
https://raw.githubusercontent.com/Congamer69/Purrtion/main/distribution/sidestore-source.json
```

Direkt hinzufügen (Link auf dem iPhone antippen, SideStore muss installiert sein):
`sidestore://source?url=https://raw.githubusercontent.com/Congamer69/Purrtion/main/distribution/sidestore-source.json`

Der Link ist das offizielle Schema aus der SideStore-Doku ([URL Schema](https://docs.sidestore.io/docs/advanced/url-schema)). Die Quelle liest SideStore wie jede andere AltStore-Quelle.

## Einmalige Einrichtung am iPhone
1. SideStore installieren und mit deiner Apple-ID anmelden (Anleitung: docs.sidestore.io).
2. In SideStore unter „Quellen“ auf „+“ tippen und die URL oben einfügen (oder den `sidestore://`-Link öffnen).
3. Purrtion in der Quelle antippen und „Laden“. Danach erscheint Purrtion unter „Meine Apps“.
4. Hattest du Purrtion bisher per Xcode installiert, ist das eine andere App (SideStore ändert die Bundle-ID für die Signatur). Sichere vorher unter Profil → Daten & Backup und stelle in der neuen App wieder her.

Die Freunde-Seite ist im IPA nicht eingebaut. Verbinde sie in der App mit dem Server-Code (Einstellungen → Freunde). Der Code bleibt bei Updates erhalten.

## Release machen
1. Version und Build in Xcode erhöhen (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) und einen Abschnitt `## <Version> …` in `CHANGELOG.md` schreiben. Daraus werden die Release-Hinweise.
2. Committen, nach `main` pushen, Tag setzen und pushen: `git tag v2.3 && git push origin v2.3`.
3. Der Workflow „iPhone-Release (SideStore)“ baut das IPA, hängt es an das Release `v2.3`, berechnet Größe und SHA-256 und trägt die Version oben in `distribution/sidestore-source.json` ein. Ältere Versionen bleiben in der Liste (Rollback).

Von Hand (zum Beispiel, wenn der GitHub-Runner das aktuelle Xcode noch nicht hat):
```
tools/build-ipa.sh v2.3
python3 tools/update_sidestore_source.py dist/Purrtion-2.3.ipa
gh release create v2.3 dist/Purrtion-2.3.ipa --notes-file …   # oder gh release upload v2.3 … --clobber
git add distribution/sidestore-source.json && git commit -m "SideStore-Quelle: 2.3" && git push
```
`tools/build-ipa.sh` baut aus einem sauberen Export des Commits und bricht ab, wenn `Firebase.plist` oder ein API-Key im IPA steckt.

`tools/build-ipa.sh` signiert App und Widget ad hoc (ohne Zertifikat), nur damit ihre Berechtigungen (HealthKit, App-Gruppe) im IPA stehen. Ohne sie fehlt nach SideStores Neu-Signieren HealthKit.

Nötig sind keine Secrets, Zertifikate oder Apple-IDs. Das IPA ist unsigniert, SideStore signiert es auf dem iPhone mit deiner Apple-ID. Der Workflow nutzt nur das eingebaute `GITHUB_TOKEN`.

## Update am iPhone
- SideStore zeigt neue Versionen unter „Meine Apps“ (nach unten ziehen zum Aktualisieren der Quellen).
- Purrtion prüft beim Start höchstens alle 6 Stunden und zeigt „Update verfügbar“ mit Hinweisen. „SideStore öffnen“ startet SideStore, dort unter „Meine Apps“ nach unten ziehen und bei Purrtion „Update“ tippen. Der Deep Link `sidestore://install?url=<IPA>` taugt dafür nicht: SideStore nennt die App dann nach dem Dateinamen und bricht mit „bundle ID does not match“ ab. „Später“ blendet die Meldung für diese Version 3 Tage aus. Unter Profil → App-Update lässt sich jederzeit von Hand prüfen.
- Daten bleiben bei einem Update erhalten, solange die Bundle-ID gleich bleibt. Sie ist `com.const.purrtion` und darf sich nie ändern (SideStore hängt selbst ein Suffix an, immer dasselbe).

## Grenzen des kostenlosen Apple-Kontos
- Die Signatur läuft nach 7 Tagen ab. SideStore erneuert sie im Hintergrund, sonst Purrtion in SideStore unter „Meine Apps“ antippen („Erneuern“).
- Höchstens 3 aktive Apps gleichzeitig, und etwa 10 App-IDs pro Woche. Das Widget zählt als eigene App-ID.
- HealthKit und App-Gruppen sind bei kostenlosen Konten eingeschränkt. Ob Apple Health und das Widget damit laufen, habe ich ohne Gerät nicht geprüft. Das Widget sucht seine App-Gruppe über `ALTAppGroups` (so macht es auch AltStore).

## Wenn ein Update nicht erscheint
1. Die Quelle im Browser öffnen: Steht oben die neue Version mit `buildVersion`? GitHub liefert Rohdateien bis zu 5 Minuten verzögert.
2. In SideStore unter „Meine Apps“ nach unten ziehen, notfalls die Quelle entfernen und neu hinzufügen.
3. Die neue Version braucht eine höhere `buildVersion` (Build-Nummer) als die installierte.
4. Fehler „SHA-256“ beim Laden: Das IPA wurde nach dem Eintragen ersetzt. `update_sidestore_source.py` erneut mit dem hochgeladenen IPA laufen lassen.
5. Läuft der GitHub-Workflow nicht durch: Unter Actions das Log ansehen. Die App braucht aktuell die iOS-27-SDK (Xcode 27). Hat der Runner sie nicht, den Release von Hand machen (siehe oben).
