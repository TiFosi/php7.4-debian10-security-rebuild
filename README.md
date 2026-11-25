# PHP 7.4 security rebuild for Debian 10 (buster) with Sury packages

Debian 10 and PHP 7.4 are EOL and the Sury repository for buster (`packages.sury.org/php buster`)
no longer exists. Hosts still running Sury `php7.4` packages on buster stop getting security fixes.

This project rebuilds the current Sury/Debian `php7.4` packaging for buster in Docker. The result
is a drop-in upgrade for the installed Sury packages, with the same package names and a `~deb10+N` version.

The packaging comes from the Debian PHP team (maintained by Ondřej Surý, same source as Sury):
<https://salsa.debian.org/php-team/php>, branch `debian/main/7.4`. Each release there includes every
PHP 7.4 security backport so far, listed in `debian/changelog`.

Requirements: Docker, git, about 5 GB of disk space, and about 30 to 60 minutes of build time.

> **Disclaimer:** provided as is, without warranty, and not actively maintained. This is a stopgap
> until you migrate to a supported Debian release and PHP version. Only build scripts and documentation
> are published here: build the packages yourself, never install PHP binaries from an untrusted source.

## 1. Get the packaging sources

```sh
git clone -b debian/main/7.4 https://salsa.debian.org/php-team/php.git php-src-deb
cd php-src-deb
git log -1 --format='%H %s'        # write down the commit you build from
cd ..
```

Check that the fix for each CVE you need is in the packaging. First, find the CVE in `debian/changelog`,
which names the release that backported it:

```sh
awk '/^php7\.4 \(/{v=$2} /CVE-2026-129289/{print v; exit}' php-src-deb/debian/changelog   # prints (1:7.4.33-36)
```

Then check that the patch is listed in `series`, otherwise it is not applied:

```sh
grep -n '<patch file name>' php-src-deb/debian/patches/series
```

Do not grep the patch files for the CVE number: recent patches are named after the GitHub advisory
(`GHSA-xxxx-xxxx-xxxx`), not the CVE, and the CVE only appears in the `Add-NEWS-entries` patch,
which changes nothing but the `NEWS` file. Look up the GHSA identifier of the CVE (in the advisory
on <https://github.com/php/php-src/security/advisories>), then search the patch names for it:

```sh
ls php-src-deb/debian/patches/ | grep -i '<GHSA id>'
```

For example, `1:7.4.33-36` backports the PHP 2026-11-19 security release (from 8.2.36). It fixes
CVE-2026-129289 (PHP-FPM request smuggling) with
`0204-Fix-GHSA-qc49-hpvq-g2w6-Drain-unread-request-bodies.patch`.
CVE-2026-109618 is fixed by `0163-Avoid-state-corruption-via-bailout.patch` (backported in `1:7.4.33-31`).
Patch numbers can change between releases: search by name, not by number.

If the CVE is not in the changelog, or the patch is not in `series`, the fix is not in the packaging yet.
You can add the upstream fix yourself.
Upstream publishes the EOL fixes as branches in <https://github.com/php/php-src>, such as
`PHP-7.4-CVE-2026-109618-109619`:

```sh
git ls-remote https://github.com/php/php-src.git 'refs/heads/PHP-7.4-CVE-*'
curl -L -o upstream.patch https://github.com/php/php-src/commit/<sha>.patch
cp upstream.patch php-src-deb/debian/patches/9999-upstream-fix.patch
echo 9999-upstream-fix.patch >> php-src-deb/debian/patches/series
(cd php-src-deb && QUILT_PATCHES=debian/patches quilt push -a && quilt pop -a)   # must apply cleanly
```

## 2. Build

```sh
mkdir -p logs
docker build -t php74-buster-build .
docker run --rm -v "$PWD/out:/out" -e OUT_UID="$(id -u):$(id -g)" \
  -e CHANGELOG_MSG='Rebuild for Debian 10 (buster) - PHP 2026-11-19 security release' \
  php74-buster-build 2>&1 | tee "logs/build-$(date +%F).log"
```

The packages are written to `out/`, for example `php7.4-fpm_7.4.33-38~deb10+1_amd64.deb`.
`OUT_UID` makes the files belong to you instead of root. The `-dbgsym` packages hold debug symbols:
you do not need to deploy them.

Every build starts again from the version in `php-src-deb/debian/changelog`, so a rebuild of the same
packaging also produces `~deb10+1`. To publish a second rebuild of the same version, raise the suffix
yourself with `-e DEB10_REV=2`.

Move or delete the previous `out/` first, otherwise the old and new packages end up mixed in it.

## 3. Test in a clean container

```sh
docker run --rm -it -v "$PWD/out:/out:ro" debian:buster bash -c '
  printf "deb http://archive.debian.org/debian buster main\ndeb http://archive.debian.org/debian-security buster/updates main\n" > /etc/apt/sources.list
  echo "Acquire::Check-Valid-Until \"false\";" > /etc/apt/apt.conf.d/99no-check-valid
  apt-get update -q
  apt-get install -y -q /out/php7.4-{cli,common,fpm,json,opcache,readline}_*.deb
  php -v && php-fpm7.4 -t && php -m'
```

Also check that the packages make no outbound telemetry. Sury's packaging carries a DNS telemetry patch,
which should be compiled out when `TELEMETRY_HOST` is undefined:

```sh
for f in out/*.deb; do
  n=$(dpkg-deb --fsys-tarfile "$f" | tar -xO 2>/dev/null | strings | grep -ic telemetry)
  [ "$n" -gt 0 ] && echo "$n $f"
done
```

The only package listed should be `php7.4-dev`: it ships the `secure_dns_telemetry.h` header and the
compiler flags (`TELEMETRY_PACKAGE`, `TELEMETRY_VERSION`) in `php-config7.4`, which is expected. The
telemetry call is only compiled when `TELEMETRY_HOST` is defined. The `-DTELEMETRY_HOST` flag must never
appear in the build log:

```sh
grep -c -- '-DTELEMETRY_HOST' logs/build-*.log    # expected: 0
```

## 4. Deploy

See [DEPLOYMENT.md](DEPLOYMENT.md).

## Getting later fixes

When a new release appears on the `debian/main/7.4` branch (a commit such as
"Update changelog for 1:7.4.33-XX"), run `git -C php-src-deb pull` and repeat steps 1 to 4.
The new packages, such as `7.4.33-39~deb10+1`, upgrade the previous ones normally.

This works as long as the branch is maintained and its build dependencies are still available on buster.
If the build fails at `mk-build-deps` or during compilation, the packaging has moved past buster.

## Credits and licenses

- PHP: [PHP License v3.01](https://www.php.net/license/).
- Debian packaging: Debian PHP team / Ondřej Surý (see `debian/copyright` in the packaging sources).
- This repository only contains build scripts and documentation.
