FROM golang:1.16-alpine3.13

RUN apk add --no-cache file

# disable CGO for ALL THE THINGS (to help ensure no libc)
ENV CGO_ENABLED 0

WORKDIR /go/src/github.com/tianon/gosu

COPY go.mod go.sum ./
RUN set -eux; \
	go mod download; \
	go mod verify

ENV BUILD_FLAGS="-v -ldflags '-d -s -w'"

COPY *.go ./

# gosu-$(dpkg --print-architecture)
RUN set -eux; \
	eval "GOARCH=amd64 go build $BUILD_FLAGS -o /go/bin/gosu-amd64"; \
	file /go/bin/gosu-amd64; \
	/go/bin/gosu-amd64 --version; \
	/go/bin/gosu-amd64 nobody id; \
	/go/bin/gosu-amd64 nobody ls -l /proc/self/fd

RUN set -eux; \
	eval "GOARCH=386 go build $BUILD_FLAGS -o /go/bin/gosu-i386"; \
	file /go/bin/gosu-i386; \
	/go/bin/gosu-i386 --version; \
	/go/bin/gosu-i386 nobody id; \
	/go/bin/gosu-i386 nobody ls -l /proc/self/fd

RUN set -eux; \
	eval "GOARCH=arm GOARM=5 go build $BUILD_FLAGS -o /go/bin/gosu-armel"; \
	file /go/bin/gosu-armel

RUN set -eux; \
	eval "GOARCH=arm GOARM=6 go build $BUILD_FLAGS -o /go/bin/gosu-armhf"; \
	file /go/bin/gosu-armhf

# boo Raspberry Pi, making life hard (armhf-is-v7 vs armhf-is-v6 ...)
#RUN set -eux; \
#	eval "GOARCH=arm GOARM=7 go build $BUILD_FLAGS -o /go/bin/gosu-armhf"; \
#	file /go/bin/gosu-armhf

RUN set -eux; \
	eval "GOARCH=arm64 go build $BUILD_FLAGS -o /go/bin/gosu-arm64"; \
	file /go/bin/gosu-arm64

RUN set -eux; \
	eval "GOARCH=mips64le go build $BUILD_FLAGS -o /go/bin/gosu-mips64el"; \
	file /go/bin/gosu-mips64el

RUN set -eux; \
	eval "GOARCH=ppc64le go build $BUILD_FLAGS -o /go/bin/gosu-ppc64el"; \
	file /go/bin/gosu-ppc64el

RUN set -eux; \
	eval "GOARCH=riscv64 go build $BUILD_FLAGS -o /go/bin/gosu-riscv64"; \
	file /go/bin/gosu-riscv64

RUN set -eux; \
	eval "GOARCH=s390x go build $BUILD_FLAGS -o /go/bin/gosu-s390x"; \
	file /go/bin/gosu-s390x

RUN set -eux; ls -lAFh /go/bin/gosu-*; file /go/bin/gosu-*
