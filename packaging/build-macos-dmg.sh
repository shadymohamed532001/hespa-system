#!/usr/bin/env bash
set -Eeuo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${HESBA_VERSION:-1.1.0}"
version="${version#v}"
output_dir="$root_dir/artifacts"
mkdir -p "$output_dir"

cd "$root_dir/frontend"
flutter build macos --release \
  --dart-define="API_BASE_URL=${API_BASE_URL:-https://hesba.alien-fit.com/api}"
app_path="$(find build/macos/Build/Products/Release -maxdepth 1 -name '*.app' -print -quit)"
if [[ -z "$app_path" ]]; then
  echo "Built macOS app was not found" >&2
  exit 1
fi
if [[ -n "${MACOS_SIGNING_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime --timestamp \
    --sign "$MACOS_SIGNING_IDENTITY" "$app_path"
fi
hdiutil create -volname "Hesba" -srcfolder "$app_path" \
  -ov -format UDZO "$output_dir/Hesba-$version-macos.dmg"
if [[ -n "${MACOS_SIGNING_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$MACOS_SIGNING_IDENTITY" \
    "$output_dir/Hesba-$version-macos.dmg"
fi
