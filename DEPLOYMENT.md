# Deployment on a Debian 10 host running Sury PHP 7.4

Replace `<host>` with the target host. The steps assume `php7.4-fpm` behind a web server.
If the host uses custom FPM units or ini files, adapt the service names and paths.

**Important:** the old Sury packages can no longer be downloaded. Back them up first (step 1),
otherwise you have no rollback.

## 0. Before

- Schedule a maintenance window, because php-fpm restarts.
- If the host is a VM or container, take a snapshot. It is the easiest rollback.
- Disable the dead Sury apt source if it is still there:

  ```sh
  sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/php.list
  ```

- List the installed packages, third-party extensions and FPM services:

  ```sh
  dpkg -l 'php7.4-*' | awk '/^ii/{print $2, $3}'
  ls /usr/lib/php/20190902/
  systemctl list-units --all 'php*'
  ```

- Find custom FPM units and make sure no package owns them, so the upgrade cannot overwrite them:

  ```sh
  systemctl cat <unit> | head -1
  dpkg -S <path shown above>    # expected: "no path found"
  ```

## 1. Backups

```sh
tar czf /root/php74-backup-etc.tgz /etc/php /usr/lib/php/20190902 /etc/systemd/system

apt install dpkg-repack   # from archive.debian.org if needed
mkdir -p /root/php74-rollback && cd /root/php74-rollback
dpkg-repack $(dpkg -l 'php7.4-*' | awk '/^ii/{print $2}')

php -v                        > /root/php74-before-version.txt
php -m                        > /root/php74-before-modules.txt
dpkg -l 'php*'                > /root/php74-before-packages.txt
ls -l /etc/php/7.4/*/conf.d   > /root/php74-before-confd.txt
systemctl list-unit-files 'php*' > /root/php74-before-services.txt
```

If a pool uses its own `PHP_INI_SCAN_DIR`, also record `PHP_INI_SCAN_DIR=<dir> php -m`.

## 2. Copy

Only copy the packages that match the installed `php7.4-*` packages (from step 0):

```sh
ssh <host> 'mkdir -p /tmp/php74-deb'
scp out/php7.4-{cli,common,fpm,...}_*_amd64.deb <host>:/tmp/php74-deb/
```

## 3. Install

```sh
# Keep all existing config files (dpkg conffiles and ucf-managed php.ini)
DEBIAN_FRONTEND=noninteractive UCF_FORCE_CONFFOLD=1 \
  apt install -o Dpkg::Options::=--force-confold /tmp/php74-deb/*.deb
php-fpm7.4 -t
systemctl restart php7.4-fpm      # or your custom unit(s)
```

## 4. Checks

- `php -v` reports the new version.
- Compare the state with the files saved in step 1 (modules, services, `conf.d`).
  The upgrade can recreate `conf.d` symlinks that were removed by hand. Disable them again with `phpdismod`.
- Check the logs, then test your applications.

Third-party extensions are not rebuilt. They should keep working (same extension API), but test them.

## 5. Rollback

```sh
dpkg -i /root/php74-rollback/*.deb
tar xzf /root/php74-backup-etc.tgz -C /
systemctl daemon-reload
systemctl restart php7.4-fpm      # or your custom unit(s)
```

Or restore the snapshot.

## 6. Next

This is a stopgap. Plan the migration to a supported Debian release and PHP version.
