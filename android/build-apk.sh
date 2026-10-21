#!/bin/zsh
# Builds the installable release APK and copies it to android/dist/Purrtion-<version>.apk.
# The APK contains no friends-server data (connect it in the app with the server code), so it can go on GitHub.
# `./build-apk.sh --private` builds one with the server from Firebase.plist built in.
# The build itself runs in $TMPDIR (see build.gradle.kts) because the project sits in an iCloud-synced folder.
set -e
cd "$(dirname "$0")"
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
[ -f local.properties ] || echo "sdk.dir=$ANDROID_HOME" > local.properties
if [ "$1" = "--private" ]; then ./gradlew -q :app:assembleRelease -Ppurrtion.public=false; else ./gradlew -q :app:assembleRelease -Ppurrtion.public=true; fi
version=$(sed -n 's/.*MARKETING_VERSION = \([0-9.]*\);.*/\1/p' ../Purrtion.xcodeproj/project.pbxproj | head -1)
mkdir -p dist
cp "${TMPDIR:-/tmp}/purrtion-android-build/app/outputs/apk/release/app-release.apk" "dist/Purrtion-$version.apk"
echo "Fertig: android/dist/Purrtion-$version.apk ($(du -h "dist/Purrtion-$version.apk" | cut -f1))"
