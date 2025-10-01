FROM golang:1.24.6-trixie

RUN set -eux; \
	apt-get install --update -y --no-install-recommends \
		arch-test \
		file \
	; \
	apt-get dist-clean

# https://github.com/tianon/fake-git
# https://github.com/tianon/fake-git/commits/HEAD
ENV FAKEGIT_COMMIT dc6774bbecc1f72de44d02bfd4385a4e6f45f807
RUN set -eux; \
	git init /opt/fake-git; \
	git -C /opt/fake-git fetch --depth 1 https://github.com/tianon/fake-git.git "$FAKEGIT_COMMIT:"; \
	git -C /opt/fake-git checkout FETCH_HEAD; \
	ln -svfT /opt/fake-git/fake-git.sh /usr/local/bin/git; \
	hash -r; \
	FAKEGIT_GO_SEMVER='v1.2.3' git --fake

# note: we cannot add "-s" here because then "govulncheck" does not work (see SECURITY.md); the ~0.2MiB increase (as of 2022-12-16, Go 1.18) is worth it
ENV BUILD_FLAGS="-v -trimpath -ldflags '-d -w' -buildvcs=true"

# disable CGO for ALL THE THINGS (to help ensure no libc)
ENV CGO_ENABLED 0

RUN set -eux; \
	{ \
		echo '#!/usr/bin/env bash'; \
		echo 'set -Eeuo pipefail -x'; \
# this scrapes our raw version number out of "version.go" (which we then use as our "commit ref" so it's "vcs.revision" in our metadata, and "cross-grade" to semver below for our fake tag so Go thinks we have a version number worth including)
		echo 'FAKEGIT_GO_REVISION="$(grep -oEm1 "[0-9][0-9.+a-z-]+" version.go)"'; \
# validate our assumptions about the above version number
		echo 'grep <<<"$FAKEGIT_GO_REVISION" -E "^[0-9]+[.][0-9]+\$"'; \
# Go *requires* semver, which is silly, but outside our control, so this takes our version numbers like "1.2" and "cross-grades" them to be like "v1.2.0", per (Go's implementation of) semver (and the VCS implementation is even stricter and requires the full triplet)
		echo 'FAKEGIT_GO_SEMVER="v${FAKEGIT_GO_REVISION}.0"'; \
		echo 'export FAKEGIT_GO_REVISION FAKEGIT_GO_SEMVER'; \
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

# satisfy Go's need for ".git" to invoke "git" (or in our case, "fake-git.sh")
RUN mkdir .git # ("touch .git" should be enough here, but Go insists it be a directory even though Git worktrees are a thing and have ".git" as a file)

COPY go.mod go.sum ./
RUN go mod download

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
RUN ARCH=loong64  GOARCH=loong64     gosu-build-and-test.sh

RUN set -eux; go version -m /go/bin/gosu-*; ls -lAFh /go/bin/gosu-*; file /go/bin/gosu-*
