FROM debian:buster

# Buster is EOL: use the Debian archive
RUN printf 'deb http://archive.debian.org/debian buster main\ndeb http://archive.debian.org/debian-security buster/updates main\n' > /etc/apt/sources.list \
 && echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential devscripts equivs fakeroot quilt git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY php-src-deb /build/php7.4
WORKDIR /build/php7.4

RUN apt-get update \
 && mk-build-deps -i -r -t 'apt-get -y --no-install-recommends' debian/control \
 && rm -rf /var/lib/apt/lists/*

COPY build.sh /build/build.sh
CMD ["/build/build.sh"]
