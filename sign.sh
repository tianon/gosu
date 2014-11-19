#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

set -x
for f in SHA256SUMS gosu*; do
	gpg --output "$f.asc" --detach-sign "$f"
done
