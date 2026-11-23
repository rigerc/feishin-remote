#!/usr/bin/env bash
# Build, sign and verify the release APK, or validate release metadata with --dry-run.
set -euo pipefail
cd "$(dirname "$0")/.."
export LC_ALL=C

if [[ "${1:-}" == --dry-run ]]; then
  exec python3 tool/release.py "${@:2}"
fi
for name in ANDROID_KEYSTORE_PATH ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD; do
  if [[ -z ${!name:-} ]]; then
    echo "Set $name to build a signed release." >&2
    exit 1
  fi
done
if [[ "$ANDROID_KEYSTORE_PATH" != /* || ! -r "$ANDROID_KEYSTORE_PATH" ]]; then
  echo "ANDROID_KEYSTORE_PATH must be an absolute path to a readable keystore." >&2
  exit 1
fi

sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
if [[ -z "$sdk" ]]; then
  echo "Set ANDROID_HOME to the Android SDK directory." >&2
  exit 1
fi
apksigner=$(find "$sdk/build-tools" -maxdepth 2 -name apksigner | sort -V | tail -1)
if [[ -z "$apksigner" ]]; then
  echo "Install Android SDK Build Tools (apksigner, aapt and aapt2)." >&2
  exit 1
fi
tools=${apksigner%/*}

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
python3 tool/release.py "$@" --output "$staging"
version=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$staging/release.json")
symbols="build/symbols/$version"
rm -rf "$symbols"
flutter build apk --release --no-pub --obfuscate --split-debug-info="$symbols"

apk="$staging/feishin-remote-$version-android.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$apk"
"$apksigner" verify --verbose --print-certs "$apk"
application_id=$(python3 -c 'import json; print(json.load(open("project.json"))["applicationId"])')
"$tools/aapt" dump badging "$apk" |
  awk -v expected="name='${application_id}'" '$1 == "package:" && $2 == expected {found=1} END {exit !found}'
# The media notification icon must survive resource shrinking.
"$tools/aapt2" dump resources "$apk" | grep 'drawable/ic_stat_feishin' >/dev/null
(
  cd "$staging"
  sha256sum "${apk##*/}" release.json RELEASE_NOTES.md > SHA256SUMS
)
mkdir -p dist
if [[ -d dist/release ]]; then
  # Replace only filenames owned by this command.
  rm -f dist/release/{feishin-remote-*-android.apk,RELEASE_NOTES.md,release.json,SHA256SUMS}
fi
mkdir -p dist/release
cp "$staging"/* dist/release/
echo "Signed release available in dist/release. Debug symbols are in $symbols."
