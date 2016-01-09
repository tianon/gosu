#!/bin/bash
set -e

usage() {
	echo "usage: $1 gosu-binary"
	echo "   ie: $1 ./gosu-amd64"
}

gosu="$1"
shift || { usage >&2; exit 1; }

dir="$(mktemp -d -t gosu-test-XXXXXXXXXX)"
trap "rm -rf '$dir'" EXIT

set -x
mkdir -p "$dir"
cp Dockerfile.test "$dir/Dockerfile"
cp "$gosu" "$dir/gosu"
docker build "$dir"
