#!/usr/bin/env bash
# Skydroid's RC SDK for a build that reads a Skydroid handheld's own sticks (README "Skydroid H12").
# The SDK is Skydroid's and proprietary, never in this repository: a build fetches it into
# android/app/libs and checks it against its sha256, whatever the source.
#   tool/skydroid_sdk.sh fetch [--require]   the SDK into android/app/libs (--require: fail without)
#   tool/skydroid_sdk.sh check APK           fail unless the APK carries Skydroid's SDK
set -euo pipefail

NAME=rcsdk-v1.9.2.aar
SHA256=e5977ba3292246bcee026defdb8563a18adc9d5573fdfb20a6880ee469f0fde2
SOURCES=(
  # Skydroid's demo
  "https://gitee.com/skydroid/rcsdk-demo/raw/master/app/libs/$NAME"
  # the same file in a public project, at a fixed commit
  "https://raw.githubusercontent.com/yangreest/Robot-V3/eeef49681177f18017193b7ba1496bd189ad4215/app/libs/$NAME"
)
LIBS="$(cd "$(dirname "$0")/.." && pwd)/android/app/libs"

fetch() {
  local require=${1:-} tmp
  if [ -f "$LIBS/$NAME" ] && echo "$SHA256  $LIBS/$NAME" | sha256sum -c --status; then
    echo "Skydroid SDK: $LIBS/$NAME is there"
    return 0
  fi
  tmp=$(mktemp)
  for url in "${SOURCES[@]}"; do
    if curl -fsSL --retry 2 --max-time 120 -o "$tmp" "$url" &&
      echo "$SHA256  $tmp" | sha256sum -c --status; then
      mkdir -p "$LIBS"
      mv "$tmp" "$LIBS/$NAME"
      echo "Skydroid SDK: $NAME from $url"
      return 0
    fi
    echo "::warning title=Skydroid SDK::$url gave no $NAME with the expected sha256"
  done
  rm -f "$tmp"
  if [ "$require" = --require ]; then
    echo "::error title=No Skydroid SDK::no source gave $NAME: without it the app cannot read the H12's sticks"
    return 1
  fi
  echo "::warning title=No Skydroid SDK::this APK drives with a gamepad or the touch sticks only"
}

check() {
  local apk=$1 found
  # proguard-rules.pro keeps Skydroid's classes by name: their descriptors are in the dex files
  found=$(unzip -p "$apk" 'classes*.dex' | grep -ac 'Lcom/skydroid/rcsdk/' || true)
  if [ "${found:-0}" -gt 0 ]; then
    echo "Skydroid SDK: in $apk"
    return 0
  fi
  echo "::error title=No Skydroid SDK in the APK::$apk cannot read the H12's sticks"
  return 1
}

case "${1:-}" in
  fetch) fetch "${2:-}" ;;
  check)
    [ $# -eq 2 ] || { echo "usage: $0 check APK" >&2; exit 2; }
    check "$2"
    ;;
  *)
    echo "usage: $0 fetch [--require] | check APK" >&2
    exit 2
    ;;
esac
