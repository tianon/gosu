#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

set -x
docker build -t gosu .
docker run --rm gosu > gosu
chmod +x gosu
./gosu
