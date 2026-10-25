#!/bin/zsh
# Builds the installable release APK and copies it to android/dist/Purrtion-<version>.apk.
# The APK has the server from Firebase.plist built in (see backend/README.md).
# The build itself runs in $TMPDIR (see build.gradle.kts) because the project sits in an iCloud-synced folder.
set -e
cd "$(dirname "$0")"
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
[ -f local.properties ] || echo "sdk.dir=$ANDROID_HOME" > local.properties
# The friends server (Firebase.plist) is built in since 3.0; `--no-server` builds one without it.
if [ "$1" = "--no-server" ]; then ./gradlew -q :app:assembleRelease -Ppurrtion.public=true; else ./gradlew -q :app:assembleRelease -Ppurrtion.public=false; fi
version=$(sed -n 's/.*MARKETING_VERSION = \([0-9.]*\);.*/\1/p' ../Purrtion.xcodeproj/project.pbxproj | head -1)
mkdir -p dist
cp "${TMPDIR:-/tmp}/purrtion-android-build/app/outputs/apk/release/app-release.apk" "dist/Purrtion-$version.apk"
echo "Fertig: android/dist/Purrtion-$version.apk ($(du -h "dist/Purrtion-$version.apk" | cut -f1))"
