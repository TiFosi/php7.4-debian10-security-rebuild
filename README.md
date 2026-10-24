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

Check that the fix for each CVE you need is in the packaging. First, find the patch file:

```sh
grep -l 'CVE-2026-109618' php-src-deb/debian/patches/*.patch
```

Then check that this file is listed in `series`, otherwise it is not applied:

```sh
grep -n '<patch file name>' php-src-deb/debian/patches/series
```

For example, `1:7.4.33-31` contains `0164-Avoid-state-corruption-via-bailout.patch`.

If either command prints nothing, the fix is not in the packaging yet. You can add the upstream fix yourself.
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
docker build -t php74-buster-build .
docker run --rm -v "$PWD/out:/out" \
  -e CHANGELOG_MSG='Rebuild for Debian 10 (buster) - CVE-2026-109618, CVE-2026-109619' \
  php74-buster-build
```

The packages are written to `out/`, for example `php7.4-fpm_7.4.33-31~deb10+1_amd64.deb`.
If you rebuild the same upstream version again, `dch` raises the suffix to `~deb10+2`, and so on.

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
for f in out/*.deb; do dpkg-deb --fsys-tarfile "$f" | tar -xO 2>/dev/null; done | strings | grep -i telemetry
```

## 4. Deploy

See [DEPLOYMENT.md](DEPLOYMENT.md).

## Getting later fixes

When a new release appears on the `debian/main/7.4` branch (a commit such as
"Update changelog for 1:7.4.33-XX"), run `git -C php-src-deb pull` and repeat steps 1 to 4.
The new packages, such as `7.4.33-32~deb10+1`, upgrade the previous ones normally.

This works as long as the branch is maintained and its build dependencies are still available on buster.
If the build fails at `mk-build-deps` or during compilation, the packaging has moved past buster.

## Credits and licenses

- PHP: [PHP License v3.01](https://www.php.net/license/).
- Debian packaging: Debian PHP team / Ondřej Surý (see `debian/copyright` in the packaging sources).
- This repository only contains build scripts and documentation.
