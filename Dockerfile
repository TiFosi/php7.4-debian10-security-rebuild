FROM debian:buster

# Buster is EOL: use the Debian archive
RUN printf 'deb http://archive.debian.org/debian buster main\ndeb http://archive.debian.org/debian-security buster/updates main\n' > /etc/apt/sources.list \
 && echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential devscripts equivs fakeroot quilt git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Install the build dependencies from debian/control alone, so that this layer stays
# cached when only the patches or the changelog change
COPY php-src-deb/debian/control /build/deps/debian/control
RUN cd /build/deps \
 && apt-get update \
 && mk-build-deps -i -r -t 'apt-get -y --no-install-recommends' debian/control \
 && rm -rf /var/lib/apt/lists/* /build/deps

COPY php-src-deb /build/php7.4
WORKDIR /build/php7.4

COPY build.sh /build/build.sh
CMD ["/build/build.sh"]
