#!/usr/bin/env bash
# GitHub-hosted Ubuntu runners install sdkmanager but may omit it from PATH.
set -euo pipefail

sdk=""
for root in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" /usr/local/lib/android/sdk; do
  if [[ -n "$root" && -d "$root" ]]; then
    sdk="$root"
    break
  fi
done
if [[ -z "$sdk" ]]; then
  echo "::error::Android SDK directory is missing on the runner."
  exit 1
fi
sdkmanager="$sdk/cmdline-tools/latest/bin/sdkmanager"
if [[ ! -x "$sdkmanager" ]]; then
  sdkmanager=""
  shopt -s nullglob
  for candidate in "$sdk"/cmdline-tools/*/bin/sdkmanager; do
    if [[ -x "$candidate" ]]; then sdkmanager="$candidate"; fi
  done
  shopt -u nullglob
fi
if [[ ! -x "$sdkmanager" ]]; then
  echo "::error::Android SDK command-line tools are missing under $sdk."
  exit 1
fi
export ANDROID_HOME="$sdk" ANDROID_SDK_ROOT="$sdk"
export PATH="$(dirname "$sdkmanager"):$sdk/platform-tools:$PATH"
printf 'ANDROID_HOME=%s\nANDROID_SDK_ROOT=%s\n' "$sdk" "$sdk" >> "$GITHUB_ENV"
printf '%s\n%s\n' "$(dirname "$sdkmanager")" "$sdk/platform-tools" >> "$GITHUB_PATH"

# Preserve Java 25 for Gradle/Flutter. Use the runner's JDK 17 for the SDK
# command-line tools when available, avoiding old SDK-tool/JDK incompatibility.
sdk_java="${JAVA_HOME_17_X64:-$JAVA_HOME}"
if [[ ! -x "$sdk_java/bin/java" ]]; then sdk_java="$JAVA_HOME"; fi
echo "Android SDK: $sdk"
echo "SDK manager: $sdkmanager"
JAVA_HOME="$sdk_java" "$sdkmanager" --sdk_root="$sdk" --version
# yes exits with SIGPIPE after sdkmanager finishes; only sdkmanager's status matters.
( set +o pipefail; yes | JAVA_HOME="$sdk_java" "$sdkmanager" --sdk_root="$sdk" --licenses >/dev/null )
JAVA_HOME="$sdk_java" "$sdkmanager" --sdk_root="$sdk" --install "platform-tools" "platforms;android-36" "build-tools;36.0.0"
test -f "$sdk/platforms/android-36/android.jar"
test -x "$sdk/build-tools/36.0.0/apksigner"
flutter config --android-sdk "$sdk" --jdk-dir="$JAVA_HOME"
echo "Android SDK and Java are ready."
