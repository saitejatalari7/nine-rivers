#!/usr/bin/env bash
# Exports the Android build with the signing secrets kept OUT of the project.
#
# The release keystore password sits in plaintext in export_presets.cfg. That
# file is gitignored, so it is not in version control, but it is readable by
# anything that can read the working directory - and losing or leaking a
# release keystore is unrecoverable: Play will not accept an app signed with a
# different key, so the app can never be updated again.
#
# Godot 4 reads these three, and they take precedence over the preset, so the
# preset fields can be left empty:
#
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH
#   GODOT_ANDROID_KEYSTORE_RELEASE_USER
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
#
# Keep them in ~/.ninerivers/android_release.env, outside the project, readable
# only by you. See issues/15-keystore-password-plaintext.md for the one-time
# move.
#
# Usage: tools/build_android.sh [aab|apk]
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET="${1:-aab}"
ENV_FILE="${NINE_RIVERS_SIGNING_ENV:-$HOME/.ninerivers/android_release.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "No signing environment at $ENV_FILE" >&2
  echo "See issues/15-keystore-password-plaintext.md - the keystore password" >&2
  echo "should live there rather than in export_presets.cfg." >&2
  exit 1
fi

# Sourced, never echoed. Nothing in this script prints the values.
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

for v in GODOT_ANDROID_KEYSTORE_RELEASE_PATH \
         GODOT_ANDROID_KEYSTORE_RELEASE_USER \
         GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; do
  if [[ -z "${!v:-}" ]]; then
    echo "$v is not set in $ENV_FILE" >&2
    exit 1
  fi
done

if [[ ! -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ]]; then
  echo "The keystore named in $ENV_FILE does not exist." >&2
  echo "Back it up somewhere durable and separate - it cannot be regenerated." >&2
  exit 1
fi

GODOT="${GODOT_BIN:-godot}"
case "$TARGET" in
  aab) PRESET="Android";               OUT="build/nine_rivers.aab" ;;
  apk) PRESET="Android APK (test device)"; OUT="build/nine_rivers.apk" ;;
  *)   echo "usage: $0 [aab|apk]" >&2; exit 2 ;;
esac

echo "Exporting $PRESET -> $OUT"
"$GODOT" --headless --path . --export-release "$PRESET" "$OUT"
echo "Done: $OUT"
