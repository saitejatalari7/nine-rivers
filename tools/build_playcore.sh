#!/usr/bin/env bash
# Builds the NineRiversPlayCore Android plugin (android_plugins/playcore) and
# copies the AARs into addons/NineRiversPlayCore/bin, where the export picks
# them up. Only needed after changing the plugin's Java source.
#
# Usage: tools/build_playcore.sh
set -euo pipefail

if [ -d "/d/Godot_Devs/.gradle" ]; then
  export GRADLE_USER_HOME="D:/Godot_Devs/.gradle"
fi
export JAVA_HOME="${JAVA_HOME:-/c/Program Files/Android/Android Studio/jbr}"
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

SRC="$ROOT/android_plugins/playcore"
if [[ ! -f "$SRC/local.properties" ]]; then
  echo "sdk.dir=${ANDROID_SDK_ROOT:-C:/Users/$USERNAME/AppData/Local/Android/Sdk}" > "$SRC/local.properties"
fi

"$ROOT/android/build/gradlew" -p "$SRC" assembleDebug assembleRelease --no-daemon -q

OUT="$ROOT/addons/NineRiversPlayCore/bin"
mkdir -p "$OUT/debug" "$OUT/release"
cp "$SRC/build/outputs/aar/NineRiversPlayCore-debug.aar" "$OUT/debug/"
cp "$SRC/build/outputs/aar/NineRiversPlayCore-release.aar" "$OUT/release/"
echo "NineRiversPlayCore AARs copied to $OUT"
