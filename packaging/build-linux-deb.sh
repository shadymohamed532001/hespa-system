#!/usr/bin/env bash
set -Eeuo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${HESBA_VERSION:-1.1.0}"
version="${version#v}"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

cd "$root_dir/frontend"
flutter build linux --release \
  --dart-define="API_BASE_URL=${API_BASE_URL:-https://hesba.alien-fit.com/api}"

mkdir -p "$stage/DEBIAN" "$stage/opt/hesba" "$stage/usr/bin" "$stage/usr/share/applications"
cp -R build/linux/x64/release/bundle/. "$stage/opt/hesba/"
ln -s /opt/hesba/hesba_desktop "$stage/usr/bin/hesba"
install -m 0644 "$root_dir/packaging/linux/hesba.desktop" "$stage/usr/share/applications/hesba.desktop"

sed "s/@VERSION@/$version/g" "$root_dir/packaging/linux/control" >"$stage/DEBIAN/control"
mkdir -p "$root_dir/artifacts"
dpkg-deb --build --root-owner-group "$stage" "$root_dir/artifacts/hesba_${version}_amd64.deb"
