FROM golang:1.13-alpine3.10

RUN apk add --no-cache file upx

ENV RUNC_VERSION v1.0.0-rc9

RUN set -eux; \
	wget -O runc.tgz "https://github.com/opencontainers/runc/archive/${RUNC_VERSION}.tar.gz"; \
	mkdir -p /go/src/github.com/opencontainers/runc; \
	tar -xf runc.tgz -C /go/src/github.com/opencontainers/runc --strip-components=1; \
	rm runc.tgz

# disable CGO for ALL THE THINGS (to help ensure no libc)
ENV CGO_ENABLED 0

ENV BUILD_FLAGS="-v -ldflags '-d -s -w'"

COPY *.go /go/src/github.com/tianon/gosu/
WORKDIR /go/src/github.com/tianon/gosu

# gosu-$(dpkg --print-architecture)
RUN set -eux; \
	eval "GOARCH=amd64 go build $BUILD_FLAGS -o /go/bin/gosu-amd64"; \
	file /go/bin/gosu-amd64; \
	upx /go/bin/gosu-amd64; \
	/go/bin/gosu-amd64 --version; \
	/go/bin/gosu-amd64 nobody id; \
	/go/bin/gosu-amd64 nobody ls -l /proc/self/fd
RUN set -eux; \
	eval "GOARCH=386 go build $BUILD_FLAGS -o /go/bin/gosu-i386"; \
	file /go/bin/gosu-i386; \
	upx /go/bin/gosu-i386; \
	/go/bin/gosu-i386 --version; \
	/go/bin/gosu-i386 nobody id; \
	/go/bin/gosu-i386 nobody ls -l /proc/self/fd
RUN set -eux; \
	eval "GOARCH=arm GOARM=5 go build $BUILD_FLAGS -o /go/bin/gosu-armel"; \
	file /go/bin/gosu-armel; \
	upx /go/bin/gosu-armel
RUN set -eux; \
	eval "GOARCH=arm GOARM=6 go build $BUILD_FLAGS -o /go/bin/gosu-armhf"; \
	file /go/bin/gosu-armhf; \
	upx /go/bin/gosu-armhf
# boo Raspberry Pi, making life hard
#RUN set -eux; \
#	eval "GOARCH=arm GOARM=7 go build $BUILD_FLAGS -o /go/bin/gosu-armhf"; \
#	file /go/bin/gosu-armhf
RUN set -eux; \
	eval "GOARCH=arm64 go build $BUILD_FLAGS -o /go/bin/gosu-arm64"; \
	file /go/bin/gosu-arm64; \
	upx /go/bin/gosu-arm64
RUN set -eux; \
	eval "GOARCH=ppc64 go build $BUILD_FLAGS -o /go/bin/gosu-ppc64"; \
	file /go/bin/gosu-ppc64; \
	upx /go/bin/gosu-ppc64
RUN set -eux; \
	eval "GOARCH=ppc64le go build $BUILD_FLAGS -o /go/bin/gosu-ppc64el"; \
	file /go/bin/gosu-ppc64el; \
	upx /go/bin/gosu-ppc64el
RUN set -eux; \
	eval "GOARCH=s390x go build $BUILD_FLAGS -o /go/bin/gosu-s390x"; \
	file /go/bin/gosu-s390x

RUN file /go/bin/gosu-*
