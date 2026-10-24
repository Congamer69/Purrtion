#!/bin/zsh
# Builds an unsigned IPA (dist/Purrtion-<version>.ipa) for SideStore, which signs it on the phone.
# It builds from a clean export of the last commit (or the ref given as $1), so files that are not in git, like
# Purrtion/Resources/Firebase.plist, can never end up in the IPA. The friends server is connected in the app with the server code.
set -e
cd "$(dirname "$0")/.."
ref="${1:-HEAD}"
work="$(mktemp -d "${TMPDIR:-/tmp}/purrtion-ipa.XXXXXX")"
trap 'rm -rf "$work"' EXIT
git archive "$ref" | tar -x -C "$work"
version=$(sed -n 's/.*MARKETING_VERSION = \([0-9.]*\);.*/\1/p' "$work/Purrtion.xcodeproj/project.pbxproj" | head -1)

xcodebuild -project "$work/Purrtion.xcodeproj" -scheme Purrtion -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' -derivedDataPath "$work/dd" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build | grep -E "error:|BUILD" || true

app="$work/dd/Build/Products/Release-iphoneos/Purrtion.app"
[ -d "$app" ] || { echo "Build fehlgeschlagen."; exit 1; }

# Safety net: no friends-server configuration and no API key in the app.
if [ -e "$app/Firebase.plist" ] || grep -rqa "AIza" "$app"; then
  echo "Abbruch: Die App enthält Freunde-Server-Daten."; exit 1
fi

mkdir -p "$work/ipa/Payload" dist
cp -R "$app" "$work/ipa/Payload/"
rm -f "dist/Purrtion-$version.ipa"
(cd "$work/ipa" && zip -qry "$OLDPWD/dist/Purrtion-$version.ipa" Payload)
echo "Fertig: dist/Purrtion-$version.ipa ($(du -h "dist/Purrtion-$version.ipa" | cut -f1)), ohne Freunde-Server."
