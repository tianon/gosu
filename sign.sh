#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

set -x
rm -f gosu*.asc SHA256SUMS.asc
for f in SHA256SUMS gosu*; do
	gpg --output "$f.asc" --detach-sign "$f"
done
ls -lFh gosu* SHA256SUMS*
