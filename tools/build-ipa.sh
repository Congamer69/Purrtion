#!/bin/zsh
# Builds an unsigned IPA (dist/Purrtion-<version>.ipa) for SideStore, which signs it on the phone.
# It builds from a clean export of the last commit (or the ref given as $1), so files that are not in git, like
# Purrtion/Resources/Firebase.plist, can never end up in the repository. The release IPA gets the local plist (the friends
# server is built in since 3.0); `--no-server` builds one without it.
set -e
cd "$(dirname "$0")/.."
noserver=0; [ "$1" = "--no-server" ] && { noserver=1; shift; }
ref="${1:-HEAD}"
work="$(mktemp -d "${TMPDIR:-/tmp}/purrtion-ipa.XXXXXX")"
trap 'rm -rf "$work"' EXIT
git archive "$ref" | tar -x -C "$work"
[ "$noserver" = 1 ] || cp Purrtion/Resources/Firebase.plist "$work/Purrtion/Resources/Firebase.plist"
version=$(sed -n 's/.*MARKETING_VERSION = \([0-9.]*\);.*/\1/p' "$work/Purrtion.xcodeproj/project.pbxproj" | head -1)

xcodebuild -project "$work/Purrtion.xcodeproj" -scheme Purrtion -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' -derivedDataPath "$work/dd" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build | grep -E "error:|BUILD" || true

app="$work/dd/Build/Products/Release-iphoneos/Purrtion.app"
[ -d "$app" ] || { echo "Build fehlgeschlagen."; exit 1; }

# The server config must be in the app, or out of it for --no-server.
if [ "$noserver" = 1 ]; then
  if [ -e "$app/Firebase.plist" ] || grep -rqa "AIza" "$app"; then echo "Abbruch: Die App enthält Server-Daten."; exit 1; fi
else
  [ -e "$app/Firebase.plist" ] || { echo "Abbruch: Firebase.plist fehlt in der App."; exit 1; }
fi

mkdir -p "$work/ipa/Payload" dist
cp -R "$app" "$work/ipa/Payload/"

# An unsigned build carries no entitlements, and SideStore only keeps the ones it finds in the app: without them HealthKit
# and the app group are gone after the re-sign ("Missing com.apple.developer.healthkit entitlement"). So sign ad hoc
# (no certificate, SideStore replaces it) just to embed them. The extension first, then the app.
payload="$work/ipa/Payload/Purrtion.app"
codesign -f -s - --timestamp=none --entitlements "$work/PurrtionWidget.entitlements" "$payload/PlugIns/PurrtionWidget.appex"
codesign -f -s - --timestamp=none --entitlements "$work/Purrtion.entitlements" "$payload"
for t in "$payload" "$payload/PlugIns/PurrtionWidget.appex"; do
  codesign -d --entitlements - "$t" 2>&1 | grep -q "application-groups" || { echo "Abbruch: Berechtigungen fehlen in $t"; exit 1; }
done
codesign -d --entitlements - "$payload" 2>&1 | grep -q "com.apple.developer.healthkit" || { echo "Abbruch: HealthKit fehlt in der App."; exit 1; }
rm -f "dist/Purrtion-$version.ipa"
(cd "$work/ipa" && zip -qry "$OLDPWD/dist/Purrtion-$version.ipa" Payload)
echo "Fertig: dist/Purrtion-$version.ipa ($(du -h "dist/Purrtion-$version.ipa" | cut -f1)), $([ "$noserver" = 1 ] && echo ohne || echo mit) Server."
