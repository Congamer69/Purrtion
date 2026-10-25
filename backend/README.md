# Purrtion – Freunde-Backend (Firebase, Spark-Tarif)

Die Freunde-Seite nutzt **Firebase Auth (anonym)**, **Cloud Firestore** und **Firebase Hosting** – alles im kostenlosen Spark-Tarif.
Die App spricht Firebase direkt über REST an (kein SDK), damit sie klein bleibt und jede Anfrage bewusst ist.

## Datenmodell
| Pfad | Inhalt | Wer darf lesen |
|---|---|---|
| `users/{uid}` | Name, Katzenfarbe, Einladungscode, `friends` (uids), `hidden`, `stats` (Kennzahlen), `updated` | ich selbst + alle uids in meinem `friends` |
| `codes/{CODE}` | `uid` zum 8-stelligen Einladungscode | jeder angemeldete Nutzer (nur Einzelabruf) |

**Freundschaft:** A trägt B in `A.friends` ein (= Anfrage, A gibt seine Werte für B frei). B findet die Anfrage über die Abfrage
`users where friends array-contains B` und nimmt an, indem B A in `B.friends` einträgt. Entfernen = sich selbst aus der Freigabe nehmen.
Geteilt werden nur Kennzahlen (Serie, Zieltreue, Health Score, Protein-/Wasser-Anteil, Aktivität, Obst & Gemüse, Ballaststoffe) und die heutigen kcal mit Tagesziel,
keine Mahlzeiten und kein Gewicht – den Gewichtstrend nur, wenn man ihn in den Einstellungen teilt.

## Server-Konto und Backup
Mit **Google-Login** (Einstellungen → Konto) wird das anonyme Konto mit einem Google-Konto verknüpft (`accounts:signInWithIdp` mit `idToken`, die uid bleibt). Der Login läuft über die Hosting-Seite `public/auth/index.html`: Die App öffnet `https://<projekt>.web.app/auth/?k=<API-Key>&p=<Projekt>&s=<zufälliger Wert>` (iPhone: `ASWebAuthenticationSession`, Android: Browser), die Seite meldet sich per Firebase Web SDK bei Google an und gibt das Google-ID-Token an `purrtion://auth?id=…&s=…` zurück. Die App prüft `s` und tauscht das Token gegen die Firebase-Anmeldung.

| Pfad | Inhalt | Wer darf |
|---|---|---|
| `backups/{uid}` | `updated`, `parts`, `entries`, `slot` (a oder b), `size`, `device`, `v` | nur diese uid, nur mit Google-Anmeldung |
| `backups/{uid}/parts/{slot}{n}` | `d`: komprimierte Bytes (raw deflate, höchstens 800 KB) | nur diese uid, nur mit Google-Anmeldung |

Das Backup ist das JSON der Sicherungsdatei, komprimiert und in Teile zu 700 KB geschnitten (höchstens 15, also rund 10 MB; ein einzelnes Firestore-Dokument darf höchstens 1 MiB groß sein). Zwei Plätze wechseln sich ab: erst die Teile des anderen Platzes, dann zeigt `backups/{uid}` darauf, dann werden die alten Teile gelöscht.

**Einmal einrichten:** Firebase-Konsole → Authentication → Anmeldemethode → **Google** aktivieren (Support-E-Mail wählen). Danach `cd backend && firebase deploy --only firestore:rules,hosting --project <id>`.

## Anfragen sparen
- Eigene Daten: **ein** Dokument, geschrieben nur bei Änderungen (SHA-256 des Inhalts), Kennzahlen etwa 20 Sekunden nach einem Eintrag, höchstens alle 2 Minuten, beim Verlassen der App und beim Herunterziehen der Freunde-Seite.
- Freunde & Anfragen: **eine** Abfrage für alle, höchstens alle 3 Minuten (Ziehen zum Aktualisieren erzwingt sie).
- Einladungscode nachschlagen: ein Lesezugriff. Die Einladungsseite liest gar nichts aus der Datenbank.
- Ergebnisse werden lokal zwischengespeichert – die Seite öffnet sofort und offline.

Grob: ~10 Schreib- und ~20 × (Anzahl Freunde) Lesezugriffe pro Person und Tag – weit unter den Gratisgrenzen (20.000 / 50.000).

## Einladungslinks
`https://<projekt>.web.app/f/<CODE>?n=<Name>` zeigt eine kleine Seite (`public/f/index.html`), die `purrtion://friend/<CODE>` öffnet.
Der Code lässt sich in der App auch von Hand eingeben.

## Einrichten (eigenes Projekt)
1. `firebase projects:create <id>` und `firebase apps:create WEB "Purrtion App" --project <id>`
2. In der Konsole **Firestore** anlegen (z. B. `eur3`) und unter Authentication **Anonym** aktivieren.
3. `cd backend && firebase deploy --only firestore:rules,hosting --project <id>`
4. `Firebase.example.plist` nach `Purrtion/Resources/Firebase.plist` kopieren und API-Key (`firebase apps:sdkconfig WEB …`),
   Projekt-ID und Einladungs-URL eintragen. Die Datei ist in `.gitignore`.

## Server in der App
Seit 3.0 steckt die Konfiguration in den Release-Apps (iPhone: `Purrtion/Resources/Firebase.plist`, Android: wird beim Bauen aus derselben Datei gelesen). Es gibt keinen Server-Code mehr, niemand muss etwas verbinden oder selbst hosten. Der API-Key ist ein öffentlicher Web-Key; geschützt wird über die Firestore-Regeln. Die Datei liegt nicht im Repository, `tools/build-ipa.sh` und `android/build-apk.sh` fügen sie beim Bauen der Releases hinzu.
- Eigener Server: Projekt wie oben einrichten, `Firebase.example.plist` nach `Purrtion/Resources/Firebase.plist` kopieren und die App selbst bauen.
- Ältere Versionen, die einen Server-Code eingefügt hatten, lesen ihn weiter, wenn die App keinen eingebauten Server hat.
