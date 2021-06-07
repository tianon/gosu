#!/usr/bin/env bash
set -Eeuo pipefail

declare -A platforms=(
	[amd64]='linux/amd64'
	[arm32v5]='linux/arm/v5'
	[arm32v6]='linux/arm/v6'
	[arm32v7]='linux/arm/v7'
	[arm64v8]='linux/arm64/v8'
	[i386]='linux/386'
	[mips64le]='linux/mips64le'
	[ppc64le]='linux/ppc64le'
	[s390x]='linux/s390x'
)

declare -A arches=(
	[alpine]='amd64 arm32v6 arm32v7 arm64v8 i386 ppc64le s390x'
	[debian]='amd64 arm32v5 arm32v7 arm64v8 i386 mips64le ppc64le s390x'
)
preferredOrder=( alpine debian )

_platformToOCI() {
	local platform="$1"; shift
	local os="${platform%%/*}"
	platform="${platform#$os/}"
	local architecture="${platform%%/*}"
	platform="${platform#$architecture/}"
	local variant="$platform"
	[ "$architecture" != "$variant" ] || variant=
	echo "{ os: $os, architecture: $architecture${variant:+, variant: $variant} }"
}

declare -A latest=()
for variant in "${preferredOrder[@]}"; do
	cat > "$variant.yml" <<-EOYAML
		image: tianon/gosu:$variant
		manifests:
	EOYAML
	for arch in ${arches[$variant]}; do
		platform="${platforms[$arch]}"
		docker build --pull --platform "$platform" --tag "tianon/gosu:$variant-$arch" - < "Dockerfile.$variant"
		: "${latest[$arch]:=$variant}"
		platform="$(_platformToOCI "$platform")"
		echo "  - { image: tianon/gosu:$variant-$arch, platform: $platform }" >> "$variant.yml"
	done
done

cat > latest.yml <<-'EOYAML'
	image: tianon/gosu:latest
	manifests:
EOYAML
mapfile -d '' sorted < <(printf '%s\0' "${!latest[@]}" | sort -z)
for arch in "${sorted[@]}"; do
	variant="${latest[$arch]}"
	docker tag "tianon/gosu:$variant-$arch" "tianon/gosu:$arch"
	platform="$(_platformToOCI "${platforms[$arch]}")"
	echo "  - { image: tianon/gosu:$arch, platform: $platform }" >> latest.yml
done

echo
echo '$ # now:'
echo
echo '$ docker push --all-tags tianon/gosu'
for variant in "${preferredOrder[@]}" latest; do
	echo "\$ manifest-tool push from-spec $variant.yml"
done
