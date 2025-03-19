FROM golang:1.24rc2-bookworm

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		arch-test \
		file \
	; \
	rm -rf /var/lib/apt/lists/*

# note: we cannot add "-s" here because then "govulncheck" does not work (see SECURITY.md); the ~0.2MiB increase (as of 2022-12-16, Go 1.18) is worth it
ENV BUILD_FLAGS="-v -trimpath -ldflags '-d -w'"

# disable CGO for ALL THE THINGS (to help ensure no libc)
ENV CGO_ENABLED 0

RUN set -eux; \
	{ \
		echo '#!/usr/bin/env bash'; \
		echo 'set -Eeuo pipefail -x'; \
		echo 'eval "go build $BUILD_FLAGS -o /go/bin/gosu-$ARCH" github.com/tianon/gosu'; \
		echo 'if go version -m "/go/bin/gosu-$ARCH" |& tee "/proc/$$/fd/1" | grep "(devel)" >&2; then exit 1; fi'; \
		echo 'file "/go/bin/gosu-$ARCH"'; \
		echo 'if arch-test "$ARCH"; then'; \
# there's a fun QEMU + Go 1.18+ bug that causes our binaries (especially on ARM arches) to hang indefinitely *sometimes*, hence the "timeout" and looping here
		echo '  try() { for (( i = 0; i < 30; i++ )); do if timeout 1s "$@"; then return 0; fi; done; return 1; }'; \
		echo '  try "/go/bin/gosu-$ARCH" --version'; \
		echo '  try "/go/bin/gosu-$ARCH" nobody id'; \
		echo '  try "/go/bin/gosu-$ARCH" nobody ls -l /proc/self/fd'; \
		echo 'fi'; \
	} > /usr/local/bin/gosu-build-and-test.sh; \
	chmod +x /usr/local/bin/gosu-build-and-test.sh

WORKDIR /go/src/github.com/tianon/gosu

COPY go.mod go.sum ./
RUN set -eux; \
	go mod download; \
	go mod verify

# install a fake Git and convince Go to use it (see comments in the script for details)
# https://github.com/golang/go/issues/50603
COPY fake-git.sh /usr/local/bin/git
RUN mkdir -p .git # 🙃 ("touch .git" should be enough here, but Go insists it be a directory even though Git worktrees are a thing and have ".git" as a file)

COPY *.go ./

# gosu-$(dpkg --print-architecture)
RUN ARCH=amd64    GOARCH=amd64       gosu-build-and-test.sh
RUN ARCH=i386     GOARCH=386         gosu-build-and-test.sh
RUN ARCH=armel    GOARCH=arm GOARM=5 gosu-build-and-test.sh
RUN ARCH=armhf    GOARCH=arm GOARM=6 gosu-build-and-test.sh
#RUN ARCH=armhf    GOARCH=arm GOARM=7 gosu-build-and-test.sh # boo Raspberry Pi, making life hard (armhf-is-v7 vs armhf-is-v6 ...)
RUN ARCH=arm64    GOARCH=arm64       gosu-build-and-test.sh
RUN ARCH=mips64el GOARCH=mips64le    gosu-build-and-test.sh
RUN ARCH=ppc64el  GOARCH=ppc64le     gosu-build-and-test.sh
RUN ARCH=riscv64  GOARCH=riscv64     gosu-build-and-test.sh
RUN ARCH=s390x    GOARCH=s390x       gosu-build-and-test.sh

RUN set -eux; go version -m /go/bin/gosu-*; ls -lAFh /go/bin/gosu-*; file /go/bin/gosu-*
