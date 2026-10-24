# SideStore mit HealthKit

Apple Health (HealthKit) läuft in Purrtion nur, wenn SideStore die Berechtigung bei Apple anfragen darf. Das offizielle SideStore tut das für kostenlose Apple-IDs nicht (es fragt nur App-Gruppen und Inter-App-Audio an, das Profil enthält HealthKit nie, die App meldet „Missing com.apple.developer.healthkit entitlement“).

Mit einem kleinen Patch geht es. Er trägt HealthKit (`HK421J6T7P`) in die Liste der erlaubten Funktionen von SideSign ein, mehr nicht. Die Idee und der Patch stammen aus [kenantan32/sidestore-healthkit](https://github.com/kenantan32/sidestore-healthkit). Hier liegt eine Kopie, damit du siehst, was gebaut wird.

Erprobt mit iPhone, kostenloser Apple-ID und dem Nightly von SideStore (Zweig `develop`): Gewicht, Ernährung und Aktivität in Apple Health funktionieren damit.

## Selbst bauen (dauert etwa 10 Minuten, kostenlos)
1. Auf GitHub ein **privates** Repository anlegen.
2. `patch_healthkit.py` in dessen Hauptordner legen und `build.yml` nach `.github/workflows/build.yml`.
3. Unter „Actions“ den Workflow „build“ starten. Er baut den Zweig `develop` des offiziellen [SideStore](https://github.com/SideStore/SideStore) (mit dem Login-Fix) auf einem GitHub-Mac, wendet den Patch an und hängt `SideStore.ipa` an ein Release. Den Zweig ändert man oben in `build.yml` (`SIDESTORE_REF`).
4. Die IPA laden (bei privatem Repository am Mac oder mit `gh release download`), per AirDrop oder iCloud aufs iPhone bringen.
5. **Vorher Purrtion sichern.** In SideStore unter „My Apps“ „+“ tippen und die IPA wählen. Das ersetzt SideStore (gleiche Bundle-ID), Konto und Apps bleiben.
6. Purrtion in SideStore aktualisieren, dann in Purrtion unter Profil → Apple Health „Zugriff auf Health neu anfragen“.

## Gut zu wissen
- Das ist ein selbstgebautes SideStore. Ein späteres Nightly aus dem offiziellen Kanal enthält den Patch nicht und nimmt HealthKit wieder weg. Bei SideStore-Updates deshalb neu bauen und wieder über „+“ installieren.
- Geht beim Ersetzen etwas schief, hilft AltServer oder Sideloadly am Computer, um SideStore neu aufzusetzen.
- Ob Apple HealthKit für kostenlose Konten zulässt, entscheidet Apple, nicht SideStore. Bei einer Ablehnung meldet SideStore beim Installieren von Purrtion einen Fehler.
- Der Build enthält keine Zugangsdaten. Wer SideStore selbst baut, muss dem Patch nicht trauen: Er ist kurz und steht in `patch_healthkit.py`.
