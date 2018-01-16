#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

set -x

docker build --pull -t gosu .

rm -f gosu* SHA256SUMS*
docker run --rm gosu sh -c 'cd /go/bin && tar -c gosu*' | tar -xv
sha256sum gosu* | tee SHA256SUMS
file gosu*
ls -lFh gosu* SHA256SUMS*

"./gosu-$(dpkg --print-architecture)" --help
