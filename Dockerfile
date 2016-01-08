FROM golang:1.5

ENV RUNC_VERSION v0.0.4
RUN mkdir -p /go/src/github.com/opencontainers \
	&& git clone -b "$RUNC_VERSION" --depth 1 https://github.com/opencontainers/runc.git /go/src/github.com/opencontainers/runc

ENV GOPATH $GOPATH:/go/src/github.com/opencontainers/runc/Godeps/_workspace

# disable CGO for ALL THE THINGS (to help ensure no libc)
ENV CGO_ENABLED 0

ENV BUILD_FLAGS -v -ldflags -d

COPY *.go /go/src/github.com/tianon/gosu/
WORKDIR /go/src/github.com/tianon/gosu

# gosu-$(dpkg --print-architecture)
RUN GOARCH=amd64       go build $BUILD_FLAGS -o /go/bin/gosu-amd64 \
	&& /go/bin/gosu-amd64 www-data id \
	&& /go/bin/gosu-amd64 www-data ls -l /proc/self/fd
RUN GOARCH=386         go build $BUILD_FLAGS -o /go/bin/gosu-i386 \
	&& /go/bin/gosu-i386 www-data id \
	&& /go/bin/gosu-i386 www-data ls -l /proc/self/fd
RUN GOARCH=arm GOARM=5 go build $BUILD_FLAGS -o /go/bin/gosu-armel
RUN GOARCH=arm GOARM=6 go build $BUILD_FLAGS -o /go/bin/gosu-armhf
#RUN GOARCH=arm GOARM=7 go build $BUILD_FLAGS -o /go/bin/gosu-armhf # boo Raspberry Pi, making life hard
RUN GOARCH=arm64       go build $BUILD_FLAGS -o /go/bin/gosu-arm64
RUN GOARCH=ppc64       go build $BUILD_FLAGS -o /go/bin/gosu-ppc64
RUN GOARCH=ppc64le     go build $BUILD_FLAGS -o /go/bin/gosu-ppc64el
