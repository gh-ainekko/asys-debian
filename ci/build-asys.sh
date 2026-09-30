#!/bin/sh
# Build the asys and asys-server .debs from the pinned upstream submodule.
# Usage: ci/build-asys.sh [UPSTREAM_DIR] [REV]
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
upstream=${1:-$here/upstream/asys}
rev=${2:-HEAD}
version=$(dpkg-parsechangelog -l "$here/asys/debian/changelog" -S Version | sed 's/-[^-]*$//')
work=$here/build/asys
rm -rf "$work"; mkdir -p "$work"
src=$work/asys-$version
git -C "$upstream" archive --format=tar --prefix="asys-$version/" "$rev" | tar -C "$work" -xf -
# Vendor the Go modules (offline build) and the private host TUI dependencies
# (noble's python3-textual is far too old). Both become part of the orig tarball.
(cd "$src/asys-inference" && go mod vendor)
PIP_BREAK_SYSTEM_PACKAGES=1 python3 -m pip install --disable-pip-version-check --no-compile --no-deps --quiet \
    --target "$src/hostdeps" -r "$src/asys-human-interface/requirements-host.txt"
touch "$src/hostdeps/.installed"
tar -C "$work" -cJf "$work/asys_$version.orig.tar.xz" "asys-$version"
cp -a "$here/asys/debian" "$src/"
(cd "$src" && dpkg-buildpackage -us -uc -b ${DPKG_BUILDPACKAGE_OPTS:--d})
ls -l "$work"/*.deb
