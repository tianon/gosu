#!/usr/bin/env sh
set -eu

#
# This script is a wrapper around "setpriv" (part of util-linux) which implements a fully gosu-compatible interface (and passes gosu's test suite).
#
# It is written in POSIX shell for maximum compatbility, but notably does *not* work with BusyBox's setpriv (as of 2024-06-03) as BusyBox does not implement enough functionality.
#

# TODO GOSU_PLEASE_LET_ME_BE_COMPLETELY_INSECURE_I_GET_TO_KEEP_ALL_THE_PIECES (block setuid/setgid) -- however, you can't effectively setuid a shell script/interpreted file, so maybe it's fine? 🤔

usage() {
	cat <<-EOU
		Usage: $0 user-spec command [args]
		   eg: $0 tianon bash
		       $0 nobody:root bash -c 'whoami && id'
		       $0 1000:1 id

		$0 license: Apache-2.0 (full text at https://github.com/tianon/gosu)

	EOU
}

case "${1:-}" in
	--help | -h | '-?') usage; exit 0 ;;
	--version | -v) echo '???'; exit 0 ;;
esac
if [ "$#" -lt 2 ]; then
	usage >&2
	exit 1
fi

spec="$1"; shift
: "${spec:=0}"
spec="${spec%:}" # "0:" is parsed by moby/sys/user the same as "0"
case "$spec" in
	*:*)
		user="${spec%%:*}"
		group="${spec#$user:}"
		[ "$group" != "$spec" ]
		: "${user:=0}"
		passwd="$(getent passwd "$user" || :)" # for HOME scraping below
		set -- --reuid "$user" --regid "$group" --clear-groups -- "$@"
		;;

	*)
		user="$spec"
		if passwd="$(getent passwd "$user")" && [ -n "$passwd" ]; then
			group="$(printf '%s' "$passwd" | cut -d: -f4)"
			set -- --reuid "$user" --regid "$group" --init-groups -- "$@"
		else
			passwd= # to be safe/explicit (for HOME scraping below)
			case "$user" in
				*[!0-9]* | '') echo >&2 "error: '$user' is not a user (and is also not numeric)"; exit 1 ;;
				*) group='0' ;;
				# (thanks to https://stackoverflow.com/a/16444570/433558 for this perfect pure-POSIX "is it fully numeric" hack!)
			esac
			set -- --reuid "$user" --regid "$group" --clear-groups -- "$@"
		fi
		;;
esac

unset HOME
HOME="$(printf '%s' "$passwd" | cut -d: -f6)"
: "${HOME:=/}" # see "setup-user.go"
export HOME

exec setpriv "$@"
