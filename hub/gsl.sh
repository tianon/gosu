#!/usr/bin/env bash
set -Eeuo pipefail

preferredOrder=( alpine debian )

dir="$(dirname "$BASH_SOURCE")"
cd "$dir"

commit="$(git log -1 --format='format:%H' HEAD -- .)"

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
	jq="${jq:+$jq, }$variant: (.[$i] | { ref: .ref, arches: .arches | keys_unsorted })"
	froms["$i"]="$from"
	(( i++ )) || :
done
arches="$(bashbrew remote arches --json "${froms[@]}" | jq -sc "{ $jq }")" # { alpine: [ "amd64", ... ], debian: [ "amd64", ... ] }

exec jq <<<"$arches" -r --arg commit "$commit" --arg version "$version" '
	map_values(select(.arches | length > 0))
	| keys_unsorted as $variants
	| with_entries(.value |= .arches) as $variantArches
	| ($variantArches | add | unique) as $arches
	| with_entries(.value |= (
		.ref
		| sub("^(docker[.]io/(library/)?)?"; "")
		| split(":")
		| if .[0] == "alpine" then
			join("") # alpine3.20, etc
		elif .[0] == "debian" or .[0] == "ubuntu" then
			.[1] | split("-")[0] # "bookworm", etc
		else empty end
	)) as $variantAlias
	| (
		reduce (
			to_entries[]
			| {
				variant: .key,
				arch: .value.arches[],
			}
		) as $m ({};
			if has($m.arch) then . else
				.[$m.arch] = $m.variant
			end
		)
	) as $archVariants
	| [
		{
			Maintainers: "Tianon Gravi <tianon@tianon.xyz> (@tianon)",
			GitRepo: "https://github.com/tianon/gosu.git",
			GitCommit: $commit,
			Directory: "hub",
			Builder: "buildkit",
		},

		reduce $arches[] as $arch (
			{
				Tags: [ $version, "latest" ],
				Architectures: $arches,
				File: "Dockerfile.\($variants[0])",
			};
			if has($arch + "-File") then . else
				"Dockerfile.\($archVariants[$arch])" as $df
				| if $df == .File then . else
					.[$arch + "-File"] = $df
				end
			end
		),

		(
			$variants[]
			| $variantAlias[.] as $alias
			| {
				Tags: [ "\($version)-\(.)", ., "\($version)-\($alias // empty)", $alias // empty ],
				Architectures: $variantArches[.],
				File: "Dockerfile.\(.)",
			},

			(
				. as $variant
				| $variantArches[.][]
				| {
					Tags: [ "\($variant)-\(.)", "\($alias // empty)-\(.)", if $archVariants[.] == $variant then . else empty end ],
					Architectures: .,
					File: "Dockerfile.\($variant)",
				}
			)
		),

		empty
	]
	| map(to_entries | map(.key + ": " + ([ .value ] | flatten | join(", "))) | join("\n"))
	| join("\n\n")
'
