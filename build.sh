#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

set -x
docker build -t gosu .
rm -f gosu*
docker run --rm gosu bash -c 'cd /go/bin && tar -c gosu*' | tar -xv
ls -lFh gosu*
./gosu-amd64
