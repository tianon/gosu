FROM golang

# cache-fill
RUN go get -d -v github.com/docker/libcontainer/user

ADD . /go/src/github.com/tianon/gosu
WORKDIR /go/src/github.com/tianon/gosu

RUN go get -d -v ./...
RUN go build -v

CMD [ "cat", "gosu" ]
