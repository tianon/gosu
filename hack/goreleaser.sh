#!/usr/bin/env sh

APPNAME=$1
DISTPATH=$2

: ${TARGETPLATFORM=}
: ${TARGETOS=}
: ${TARGETARCH=}
: ${TARGETVARIANT=}
: ${CGO_ENABLED=}
: ${GOARCH=}
: ${GOOS=}
: ${GOARM=}
: ${GOMIPS=}
: ${GOBIN=}
: ${GIT_REF=}

set -eu

usage() {
  echo "usage: $0 <appname> <distpath>"
  exit 1
}

if [ -z "$APPNAME" ] || [ -z "$DISTPATH" ]; then
  usage
fi

if [ -n "$TARGETPLATFORM" ]; then
  os="$(echo $TARGETPLATFORM | cut -d"/" -f1)"
  arch="$(echo $TARGETPLATFORM | cut -d"/" -f2)"
  if [ -n "$os" ] && [ -n "$arch" ]; then
    export GOOS="$os"
    export GOARCH="$arch"
    if [ "$arch" = "arm" ]; then
      case "$(echo $TARGETPLATFORM | cut -d"/" -f3)" in
      "v5")
        export GOARM="5"
        ;;
      "v6")
        export GOARM="6"
        ;;
      *)
        export GOARM="7"
        ;;
      esac
    fi
  fi
fi

if [ -n "$TARGETOS" ]; then
  export GOOS="$TARGETOS"
fi

if [ -n "$TARGETARCH" ]; then
  export GOARCH="$TARGETARCH"
fi

if [ "$TARGETARCH" = "arm" ]; then
  if [ -n "$TARGETVARIANT" ]; then
    case "$TARGETVARIANT" in
    "v5")
      export GOARM="5"
      ;;
    "v6")
      export GOARM="6"
      ;;
    *)
      export GOARM="7"
      ;;
    esac
  else
    export GOARM="7"
  fi
fi

if case $TARGETARCH in "mips"*) true;; *) false;; esac; then
  if [ -n "$TARGETVARIANT" ]; then
    export GOMIPS="$TARGETVARIANT"
  else
    export GOMIPS="hardfloat"
  fi
fi

if [ "$GOOS" = "wasi" ]; then
  export GOOS="js"
fi

if [ -z "$GOBIN" ] && [ -n "$GOPATH" ] && [ -n "$GOARCH" ] && [ -n "$GOOS" ]; then
  export PATH=${GOPATH}/bin/${GOOS}_${GOARCH}:${PATH}
fi

cat > ./.goreleaser.yml <<EOL
project_name: ${APPNAME}
dist: ${DISTPATH}

builds:
  -
    ldflags:
      - -s -w -X "main.Version={{ .Version }}"
    env:
      - CGO_ENABLED=0
    goos:
      - ${GOOS}
    goarch:
      - ${GOARCH}
    goarm:
      - ${GOARM}
    gomips:
      - ${GOMIPS}
    hooks:
      post:
        - cp "{{ .Path }}" /usr/local/bin/${APPNAME}

archives:
  -
    replacements:
      386: i386
      amd64: x86_64
    format_overrides:
      - goos: windows
        format: zip
    files:
      - LICENSE
      - README.md

release:
  disable: true
EOL

gitTag=""
case "$GIT_REF" in
  refs/tags/v*)
    gitTag="${GIT_REF#refs/tags/}"
    export GORELEASER_CURRENT_TAG=$gitTag
    ;;
  *)
    if gitTag=$(git tag --points-at HEAD --sort -version:creatordate | head -n 1); then
      if [ -z "$gitTag" ]; then
        gitTag=$(git describe --tags --abbrev=0)
      fi
    fi
    ;;
esac
echo "git tag found: ${gitTag}"

gitDirty="true"
if git describe --exact-match --tags --match "$gitTag" >/dev/null 2>&1; then
  gitDirty="false"
fi
echo "git dirty: ${gitDirty}"

flags=""
if [ "$gitDirty" = "true" ]; then
  flags="--snapshot"
fi

set -x
/usr/local/bin/goreleaser release $flags
