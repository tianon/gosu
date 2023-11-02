#!/usr/bin/env bash
set -Eeuo pipefail

preferredOrder=( alpine debian )

dir="$(dirname "$BASH_SOURCE")"
cd "$dir"

commit="$(git log -1 --format='format:%H' HEAD -- .)"
cat <<-EOH
	Maintainers: Tianon Gravi <tianon@tianon.xyz> (@tianon)
	GitRepo: https://github.com/tianon/gosu.git
	GitCommit: $commit
	Directory: hub
	Builder: buildkit
EOH

version=
i=0; jq=; froms=()
for variant in "${preferredOrder[@]}"; do
	from="$(awk 'toupper($1) == "FROM" { print $2; exit }' "Dockerfile.$variant")" # TODO multi-stage?
	variantVersion="$(awk 'toupper($1) == "ENV" && toupper($2) == "GOSU_VERSION" { print $3; exit }' "Dockerfile.$variant")"
	version="${version:-$variantVersion}"
	if [ "$version" != "$variantVersion" ]; then
		echo >&2 "error: mismatched version in '$variant' ('$version' vs '$variantVersion')"
		exit 1
	fi
	jq="${jq:+$jq, }$variant: (.[$i].arches | keys_unsorted)"
	froms["$i"]="$from"
	(( i++ )) || :
done
arches="$(bashbrew remote arches --json "${froms[@]}" | jq -sc "{ $jq }")" # { alpine: [ "amd64", ... ], debian: [ "amd64", ... ] }

queue="$(jq <<<"$arches" -r 'to_entries | map(@sh "variant=\(.key)\narch=\(.value[])") | map(@sh) | join("\n")')"
eval "queue=( $queue )"

declare -A seenArches=()
for item in "${queue[@]}"; do
	eval "$item" # variant=yyy arch=xxx
	[ -n "$variant" ]
	[ -n "$arch" ]
	tags="$variant-$arch"
	sharedTags="$variant, $version-$variant"
	if [ -z "${seenArches["$arch"]:-}" ]; then
		tags+=", $arch"
		sharedTags+=", $version, latest"
	fi
	echo
	echo "Tags: $tags"
	[ -z "$sharedTags" ] || echo "SharedTags: $sharedTags"
	echo "Architectures: $arch"
	echo "File: Dockerfile.$variant"
	: "${seenArches["$arch"]:=1}"
done
