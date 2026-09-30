#!/bin/sh
# Build the asys-images .deb: docker build upstream images, save them with
# versioned tags, compress, wrap with dpkg-deb. Needs Docker and network.
# Usage: ci/build-images.sh [UPSTREAM_DIR] [--no-build]
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
upstream=${1:-$here/upstream/asys}
debversion=$(dpkg-parsechangelog -l "$here/asys/debian/changelog" -S Version)
upstream_version=${debversion%%-*}
images="asys-runtime asys-workers asys-worlds asys-bpmn asys-human-interface asys-env-default"
work=$here/build/asys-images
rm -rf "$work"; mkdir -p "$work"
if [ "${2:-}" != --no-build ]; then
    (cd "$upstream" && make build)
fi
pkg=$work/asys-images_${debversion}_amd64
mkdir -p "$pkg/DEBIAN" "$pkg/usr/share/asys/images" "$pkg/usr/sbin"
: > "$pkg/usr/share/asys/images/manifest"
tagged=""
for name in $images; do
    docker tag "$name:dev" "$name:$upstream_version"
    tagged="$tagged $name:$upstream_version"
    echo "$name $upstream_version" >> "$pkg/usr/share/asys/images/manifest"
done
docker save $tagged | zstd -T0 -19 -q -o "$pkg/usr/share/asys/images/asys-images.tar.zst"
install -m 0755 "$here/asys-images/asys-images-load" "$pkg/usr/sbin/"
install -m 0755 "$here/asys-images/postinst" "$pkg/DEBIAN/"
sed -e "s/@VERSION@/$debversion/" -e "s/@UPSTREAM@/$upstream_version/" "$here/asys-images/control.in" > "$pkg/DEBIAN/control"
size=$(du -sk "$pkg/usr" | cut -f1); echo "Installed-Size: $size" >> "$pkg/DEBIAN/control"
(cd "$pkg" && find usr -type f -exec md5sum {} + > DEBIAN/md5sums)
fakeroot dpkg-deb -Zzstd -z0 --build "$pkg" "$work/" >/dev/null 2>&1 || fakeroot dpkg-deb -Znone --build "$pkg" "$work/"
rm -rf "$pkg"
ls -l "$work"/*.deb
