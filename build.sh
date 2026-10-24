#!/bin/sh
set -eu
cd /build/php7.4

export DEBEMAIL="${DEBEMAIL:-builder@localhost}" DEBFULLNAME="${DEBFULLNAME:-Local build}"
dch --force-distribution -D buster -l '~deb10+' \
    "${CHANGELOG_MSG:-Rebuild for Debian 10 (buster)}"

DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" dpkg-buildpackage -b -us -uc

mkdir -p /out
cp ../*.deb ../*.buildinfo ../*.changes /out/
