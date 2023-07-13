#!/usr/bin/env bash
set -Eeuo pipefail

# a wrapper / replacement for "govulncheck" which allows for excluding vulnerabilities
# (https://github.com/golang/go/issues/59507)

excludeVulns="$(jq -nc '[

	# https://pkg.go.dev/vuln/GO-2023-1840
	# we already mitigate setuid in our code
	"GO-2023-1840", "CVE-2023-29403",
	# (https://github.com/tianon/gosu/issues/128#issuecomment-1607803883)

	empty # trailing comma hack (makes diffs smaller)
]')"
export excludeVulns

if ! command -v govulncheck > /dev/null; then
	govulncheck() {
		local user; user="$(id -u):$(id -g)"
		local args=(
			--rm --interactive --init
			--user "$user"
			--env HOME=/tmp
			--env GOPATH=/tmp/go
			--volume govulncheck:/tmp
			--env CGO_ENABLED=0
			--mount "type=bind,src=$PWD,dst=/wd,ro"
			--workdir /wd
			"${GOLANG_IMAGE:-golang:latest}"
			sh -euc '
				go install golang.org/x/vuln/cmd/govulncheck@latest > /dev/null
				exec "$GOPATH/bin/govulncheck" "$@"
			' --
		)
		docker run "${args[@]}" "$@"
	}
fi

if out="$(govulncheck "$@")"; then
	printf '%s\n' "$out"
	exit 0
fi

json="$(govulncheck -json "$@")"

vulns="$(jq <<<"$json" -cs 'map(select(has("osv")) | .osv)')"
if [ "$(jq <<<"$vulns" -r 'length')" -le 0 ]; then
	printf '%s\n' "$out"
	exit 1
fi

filtered="$(jq <<<"$vulns" -c '
	(env.excludeVulns | fromjson) as $exclude
	| map(select(
		.id as $id
		| $exclude | index($id) | not
	))
')"

text="$(jq <<<"$filtered" -r 'map("- \(.id) (aka \(.aliases | join(", ")))\n\n\t\(.details | gsub("\n"; "\n\t"))") | join("\n\n")')"

if [ -z "$text" ]; then
	printf 'No vulnerabilities found.\n'
	exit 0
else
	printf '%s\n' "$text"
	exit 1
fi
