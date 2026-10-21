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

## Server-Code
Die App braucht keine eingebaute Konfiguration. Ein Server-Code `purrtion-server:<base64url von {"k":API-Key,"p":Projekt-ID,"i":Einladungs-URL}>`
wird in Einstellungen → Freunde eingefügt und unter `friends.server` gespeichert (auch in der Sicherung enthalten).
- `python3 tools/server_code.py` gibt den Code aus `Firebase.plist` aus. Verbundene Apps können ihn unter „Server-Code teilen“ weitergeben.
- Builds mit eingebauter `Firebase.plist` (iOS, Android `--private`) speichern ihre Werte beim ersten Start ebenfalls dort, damit sie ein Update auf eine Version ohne eingebaute Werte überstehen.
- Der API-Key ist ein öffentlicher Web-Key, geschützt wird über die Firestore-Regeln. Trotzdem gehört er nicht ins Repository.
