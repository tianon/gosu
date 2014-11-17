FROM golang:cross

RUN mkdir -p /go/src/github.com/docker \
	&& git clone https://github.com/docker/libcontainer.git /go/src/github.com/docker/libcontainer \
	&& cd /go/src/github.com/docker/libcontainer \
	&& git checkout --quiet 4ae31b6ceb2c2557c9f05f42da61b0b808faa5a4

ENV GOPATH $GOPATH:/go/src/github.com/docker/libcontainer/vendor

# disable CGO for ALL THE THINGS (to help ensure no libc)
ENV CGO_ENABLED 0

COPY *.go /go/src/github.com/tianon/gosu/
WORKDIR /go/src/github.com/tianon/gosu

# gosu-$(dpkg --print-architecture)
RUN GOARCH=amd64       go build -v -ldflags -d -o /go/bin/gosu-amd64
RUN GOARCH=386         go build -v -ldflags -d -o /go/bin/gosu-i386
RUN GOARCH=arm GOARM=5 go build -v -ldflags -d -o /go/bin/gosu-armel
RUN GOARCH=arm GOARM=6 go build -v -ldflags -d -o /go/bin/gosu-armhf
#RUN GOARCH=arm GOARM=7 go build -v -ldflags -d -o /go/bin/gosu-armhf # boo Raspberry Pi, making life hard
