# syntax=docker/dockerfile:1.2
ARG GO_VERSION=1.14

FROM golang:${GO_VERSION}-alpine AS base
RUN apk add --no-cache git linux-headers musl-dev
WORKDIR /src

FROM base AS vendored
RUN --mount=type=bind,target=.,rw \
  --mount=type=cache,target=/go/pkg/mod \
  go mod tidy && go mod download && \
  mkdir /out && cp go.mod go.sum /out

FROM scratch AS update
COPY --from=vendored /out /

FROM vendored AS validate
RUN --mount=type=bind,target=.,rw \
  git add -A && cp -rf /out/* .; \
  if [ -n "$(git status --porcelain -- go.mod go.sum)" ]; then \
    echo >&2 'ERROR: Vendor result differs. Please vendor your package with "docker buildx bake vendor-update"'; \
    git status --porcelain -- go.mod go.sum; \
    exit 1; \
  fi
