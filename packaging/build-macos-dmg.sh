#!/usr/bin/env bash
set -Eeuo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${HESBA_VERSION:-1.1.0}"
output_dir="$root_dir/artifacts"
mkdir -p "$output_dir"

cd "$root_dir/frontend"
flutter build macos --release \
  --dart-define="API_BASE_URL=${API_BASE_URL:-http://localhost:3000/api}"
hdiutil create -volname "Hesba" -srcfolder "build/macos/Build/Products/Release/Hesba.app" \
  -ov -format UDZO "$output_dir/Hesba-$version-macos.dmg"
