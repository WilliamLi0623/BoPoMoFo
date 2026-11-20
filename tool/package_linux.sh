#!/usr/bin/env bash
# Packages the Flutter Linux release bundle as a .tar.gz and a .deb.
# Usage: tool/package_linux.sh <version> <output-dir>
# Run `flutter build linux --release` in app/bopomofo first.
set -euo pipefail

version="${1:?version required, e.g. 0.2.1}"
out="${2:?output directory required}"
root="$(cd "$(dirname "$0")/.." && pwd)"
bundle="$root/app/bopomofo/build/linux/x64/release/bundle"
icon="$root/app/bopomofo/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
app_id='io.github.williamli0623.bopomofo'

test -x "$bundle/bopomofo" || { echo "Missing $bundle/bopomofo; build the Linux release first." >&2; exit 1; }
mkdir -p "$out"

# Debian versions may not contain '-' outside the revision; map 1.2.3-rc.1 to 1.2.3~rc.1.
deb_version="${version//-/\~}"

# 1. Portable archive.
tar_name="bopomofo-${version}-linux-x64"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
cp -a "$bundle" "$staging/$tar_name"
tar -C "$staging" -czf "$out/$tar_name.tar.gz" "$tar_name"

# 2. Debian package: bundle in /opt/bopomofo, launcher in /usr/bin.
pkg="$staging/deb"
mkdir -p "$pkg/DEBIAN" "$pkg/opt/bopomofo" "$pkg/usr/bin" \
  "$pkg/usr/share/applications" "$pkg/usr/share/icons/hicolor/192x192/apps"
cp -a "$bundle/." "$pkg/opt/bopomofo/"
ln -s /opt/bopomofo/bopomofo "$pkg/usr/bin/bopomofo"
install -m 644 "$icon" "$pkg/usr/share/icons/hicolor/192x192/apps/$app_id.png"
cat > "$pkg/usr/share/applications/$app_id.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Bopomofo
Comment=Learn Bopomofo from what you already know
Exec=/opt/bopomofo/bopomofo
Icon=$app_id
Terminal=false
Categories=Education;
StartupWMClass=$app_id
EOF
installed_kb="$(du -sk "$pkg/opt" | cut -f1)"
cat > "$pkg/DEBIAN/control" <<EOF
Package: bopomofo
Version: $deb_version
Section: education
Priority: optional
Architecture: amd64
Maintainer: WilliamLi0623 <61577379+WilliamLi0623@users.noreply.github.com>
Installed-Size: $installed_kb
Depends: libgtk-3-0t64 | libgtk-3-0, libgstreamer1.0-0, libgstreamer-plugins-base1.0-0, gstreamer1.0-plugins-good
Description: Local-first app for learning Bopomofo
 Learn Bopomofo (Zhuyin) symbols from pinyin, sounds or from scratch.
 Guest mode keeps learning progress on this device.
EOF
dpkg-deb --root-owner-group --build "$pkg" "$out/bopomofo_${deb_version}_amd64.deb" >/dev/null

(cd "$out" && sha256sum "$tar_name.tar.gz" "bopomofo_${deb_version}_amd64.deb" > "bopomofo-${version}-linux.sha256")
ls -l "$out"
