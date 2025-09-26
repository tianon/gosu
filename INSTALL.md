# Installation

We assume installation inside Docker (probably not the right tool for most use-cases outside Docker), and that you don't have either `wget` or `ca-certificates` already installed -- adjust (and version bump `GOSU_VERSION`) as necessary!

## `FROM debian`

[Debian 9 ("Debian Stretch") or newer](https://packages.debian.org/gosu):

```dockerfile
RUN set -eux; \
	apt-get install --update -y gosu; \
	apt-get dist-clean; \
# verify that the binary works
	gosu nobody true
```

Newer `gosu` releases:

```dockerfile
ENV GOSU_VERSION 1.19
RUN set -eux; \
# save list of currently installed packages for later so we can clean up
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get install --update -y --no-install-recommends ca-certificates gnupg wget; \
	\
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	\
# verify the signature
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	\
# clean up fetch dependencies
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	apt-get dist-clean; \
	\
	chmod +x /usr/local/bin/gosu; \
# verify that the binary works
	gosu --version; \
	gosu nobody true
```

Note: on Debian versions older than Trixie, you'll need to swap `apt-get dist-clean` for `rm -rf /var/lib/apt/lists/*` and remove `--update` in favor of an explicit pre-call to `apt-get update`.

## `FROM alpine` (3.7+)

```dockerfile
ENV GOSU_VERSION 1.19
RUN set -eux; \
	\
	apk add --no-cache --virtual .gosu-deps \
		ca-certificates \
		dpkg \
		gnupg \
	; \
	\
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	\
# verify the signature
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	\
# clean up fetch dependencies
	apk del --no-network .gosu-deps; \
	\
	chmod +x /usr/local/bin/gosu; \
# verify that the binary works
	gosu --version; \
	gosu nobody true
```

## `FROM centos|oraclelinux|...|ubi|...` (RPM-based distro)

```dockerfile
ENV GOSU_VERSION 1.19
RUN set -eux; \
	\
	rpmArch="$(rpm --query --queryformat='%{ARCH}' rpm)"; \
	case "$rpmArch" in \
		aarch64) dpkgArch='arm64' ;; \
		armv[67]*) dpkgArch='armhf' ;; \
		i[3456]86) dpkgArch='i386' ;; \
		ppc64le) dpkgArch='ppc64el' ;; \
		riscv64 | s390x | loongarch64) dpkgArch="$rpmArch" ;; \
		x86_64) dpkgArch='amd64' ;; \
		*) echo >&2 "error: unknown/unsupported architecture '$rpmArch'"; exit 1 ;; \
	esac; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	\
# verify the signature
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	\
	chmod +x /usr/local/bin/gosu; \
# verify that the binary works
	gosu --version; \
	gosu nobody true
```

Notes:

- `gosu`'s `armhf` builds are ARMv6 (not ARMv7 as they might be in Debian proper) thanks to Raspbian, hence the `armv6` allowance above
- `rpm` architecture values sourced from https://rpmfind.net/linux/rpm2html/search.php?query=rpm

## Others / Lazy Method

```dockerfile
COPY --from=tianon/gosu /gosu /usr/local/bin/
```
