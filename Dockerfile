# syntax=docker/dockerfile:1.2
ARG GO_VERSION=1.14
ARG GORELEASER_VERSION=0.157.0

FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine AS base
ARG GORELEASER_VERSION
RUN apk add --no-cache ca-certificates curl gcc file git linux-headers musl-dev tar
RUN wget -qO- https://github.com/goreleaser/goreleaser/releases/download/v${GORELEASER_VERSION}/goreleaser_Linux_x86_64.tar.gz | tar -zxvf - goreleaser \
  && mv goreleaser /usr/local/bin/goreleaser
WORKDIR /src

FROM base AS gomod
RUN --mount=type=bind,target=.,rw \
  --mount=type=cache,target=/go/pkg/mod \
  go mod tidy && go mod download

FROM gomod AS build
ARG TARGETPLATFORM
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG GIT_REF
RUN --mount=type=bind,target=/src,rw \
  --mount=type=cache,target=/root/.cache/go-build \
  --mount=target=/go/pkg/mod,type=cache \
  ./hack/goreleaser.sh "gosu" "/out"

FROM scratch AS artifacts
COPY --from=build /out/*.tar.gz /
COPY --from=build /out/*.zip /

FROM alpine AS test-alpine
COPY --from=build /usr/local/bin/gosu /usr/local/bin/gosu
RUN cut -d: -f1 /etc/group | xargs -n1 addgroup nobody
RUN chgrp nobody /usr/local/bin/gosu && chmod +s /usr/local/bin/gosu
USER nobody
ENV HOME /omg/really/gosu/nowhere
# now we should be nobody, ALL groups, and have a bogus useless HOME value
WORKDIR /src
RUN --mount=type=bind,target=/src \
  ./hack/test.sh

FROM debian:buster-slim AS test-debian
COPY --from=build /usr/local/bin/gosu /usr/local/bin/gosu
RUN cut -d: -f1 /etc/group | xargs -n1 -I'{}' usermod -aG '{}' nobody
# emulate Alpine's "games" user (which is part of the "users" group)
RUN usermod -aG users games
RUN chgrp nogroup /usr/local/bin/gosu && chmod +s /usr/local/bin/gosu
USER nobody
ENV HOME /omg/really/gosu/nowhere
# now we should be nobody, ALL groups, and have a bogus useless HOME value
WORKDIR /src
RUN --mount=type=bind,target=/src \
  ./hack/test.sh

FROM scratch
COPY --from=build /usr/local/bin/gosu /
