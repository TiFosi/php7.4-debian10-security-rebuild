#!/bin/sh
set -eu
cd /build/php7.4

export DEBEMAIL="${DEBEMAIL:-builder@localhost}" DEBFULLNAME="${DEBFULLNAME:-Local build}"
version="$(dpkg-parsechangelog -S Version)~deb10+${DEB10_REV:-1}"
dch --force-distribution --force-bad-version -D buster -v "$version" \
    "${CHANGELOG_MSG:-Rebuild for Debian 10 (buster)}"

DEB_BUILD_OPTIONS="nocheck parallel=$(nproc)" dpkg-buildpackage -b -us -uc

mkdir -p /out
cp ../*.deb ../*.buildinfo ../*.changes /out/
if [ -n "${OUT_UID:-}" ]; then
    chown "$OUT_UID" /out /out/*
fi
