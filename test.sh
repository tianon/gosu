#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
	echo "usage: $0 [--platform] gosu-binary"
	echo "   eg: $0 ./gosu-amd64"
	echo "       $0 --debian ./gosu-amd64"
}

df='Dockerfile.test-alpine'
case "${1:-}" in
	--alpine | --debian)
		df="Dockerfile.test-${1#--}"
		shift
		;;
esac

gosu="${1:-}"
shift || { usage >&2; exit 1; }
[ -f "$gosu" ] || { usage >&2; exit 1; }

trap '{ set +x; echo; echo FAILED; echo; } >&2' ERR

set -x

dir="$(mktemp -d -t gosu-test-XXXXXXXXXX)"
base="$(basename "$dir")"
img="gosu-test:$base"
trap "rm -rf '$dir'" EXIT
cp -T "$df" "$dir/Dockerfile"
cp -T "$gosu" "$dir/gosu"
docker build -t "$img" "$dir"
rm -rf "$dir"
trap - EXIT

trap "docker rm -f '$base' > /dev/null; docker rmi -f '$img' > /dev/null" EXIT

# using explicit "--init=false" in case dockerd is running with "--init" (because that will skew our process numbers)
docker run -d --init=false --name "$base" "$img" gosu root sleep 1000
sleep 1 # give it plenty of time to get through "gosu" and into the "sleep"
[ "$(docker top "$base" | wc -l)" = 2 ]
# "docker top" should have only two lines
# -- ps headers and a single line for the single process running in the container
