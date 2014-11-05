FROM golang

RUN mkdir -p /go/src/github.com/docker \
	&& git clone https://github.com/docker/libcontainer.git /go/src/github.com/docker/libcontainer
ENV GOPATH $GOPATH:/go/src/github.com/docker/libcontainer/vendor
# TODO pin specific commit

# cache-fill
RUN go get -d -v github.com/docker/libcontainer/namespaces

COPY . /go/src/github.com/tianon/gosu
WORKDIR /go/src/github.com/tianon/gosu

RUN go get -d -v ./...
RUN go build -v

CMD [ "cat", "gosu" ]
