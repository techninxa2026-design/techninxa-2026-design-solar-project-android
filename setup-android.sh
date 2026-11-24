#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
command -v flutter >/dev/null || { echo 'Install Flutter 3.35.7 and Android SDK.' >&2; exit 1; }
if [[ ! -f android/gradlew || ! -f android/gradle/wrapper/gradle-wrapper.jar ]]; then
  temp=$(mktemp -d); trap 'rm -rf "$temp"' EXIT
  flutter create --platforms=android --org com.techninxa --project-name idcolda_ms "$temp"
  cp "$temp/android/gradlew" "$temp/android/gradlew.bat" android/
  cp "$temp/android/gradle/wrapper/gradle-wrapper.jar" android/gradle/wrapper/
  chmod +x android/gradlew
fi
flutter pub get
dart format lib test
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
if [[ ${1:-} == '--build-debug' ]]; then flutter build apk --debug; fi
