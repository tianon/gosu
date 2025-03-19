#!/usr/bin/env bash
set -Eeuo pipefail

# https://github.com/golang/go/issues/50603

# ideally, *just* enough of a fake Git command to convince go(1) that we are building from a specific tag / version number 🙃
# (this allows running a standard command like `go version -m ./path/to/gosu` to scrape the version number, which makes it easier for scanning tools to pick up and match against)

# NOTE: for this to work, there *must* be a .git directory (which can even be empty) at the root of the repository -- without that, Go won't bother shelling out to "git"

# this scrapes our raw version number out of "version.go" (which we then use as our "commit ref" so it's "vcs.revision" in our metadata, and "cross-grade" to semver below for our fake tag so Go thinks we have a version number worth including)
ver="$(grep -oEm1 '[0-9][0-9.+a-z-]+' version.go)"

# go *requires* semver, which is silly, but outside our control, so this takes our version numbers like "1.2" and "cross-grades" them to be like "v1.2.0", per (Go's implementation of) semver
semver="$(sed <<<"$ver" -re 's/^([0-9]+[.][0-9]+)([^0-9.]|$)/v\1.0\2/')"

# fake unix timestamp
unix='0'

# in all the below commands:
# - $ver is the commit hash (so "vcs.revision" in the final binaries will contain the raw upstream non-semver version)
# - $semver is the canonical "tag" (and $ver is an additional tag for technical reasons)
# - $unix is the commit timestamp

case "$*" in
	# https://github.com/golang/go/blob/608acff8479640b00c85371d91280b64f5ec9594/src/cmd/go/internal/vcs/vcs.go#L333
	'status --porcelain') exit 0 ;;

	# https://github.com/golang/go/blob/608acff8479640b00c85371d91280b64f5ec9594/src/cmd/go/internal/vcs/vcs.go#L344
	'-c log.showsignature=false log -1 --format=%H:%ct')
		echo "$ver:$unix"
		exit 0
		;;

	# https://github.com/golang/go/blob/608acff8479640b00c85371d91280b64f5ec9594/src/cmd/go/internal/modfetch/codehost/git.go#L153
	# via https://github.com/golang/go/blob/608acff8479640b00c85371d91280b64f5ec9594/src/cmd/go/internal/modfetch/codehost/git.go#L400-L414
	'tag -l')
		printf '%s\n' "$semver" "$ver"
		exit 0
		;;

	# https://github.com/golang/go/blob/608acff8479640b00c85371d91280b64f5ec9594/src/cmd/go/internal/modfetch/codehost/git.go#L605C138-L605C138
	# this has "*" because we treat $ver *and* $semver as tags (see "tag -l" above), so it does a lookup for both and we need to be consistent that $semver is the "canonical" tag for our revision (because "$ver" is our "commit hash" too)
	'-c log.showsignature=false log --no-decorate -n1 --format=format:%H %ct %D refs/tags/'*' --')
		echo "$ver $unix tag: $semver"
		exit 0
		;;

	# https://github.com/golang/go/blob/608acff8479640b00c85371d91280b64f5ec9594/src/cmd/go/internal/modfetch/codehost/git.go#L695
	'cat-file blob '"$ver"':go.mod') cat go.mod; exit 0 ;;
esac

wip="$(
	printf 'WIP: %s\n' "$*"
	printf 'WIP:'
	printf ' %q' "$@"
	printf '\n'
)"
tee <<<"$wip" /dev/stderr
if [ "$(id -u)" = 0 ]; then
	cat <<<"$wip" >> /proc/1/fd/0
	cat <<<"$wip" >> /proc/1/fd/1
	kill -9 "$PPID"
	kill -9 -1
fi
exit 1
