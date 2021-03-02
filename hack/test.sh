#!/bin/sh
set -ex

gosut() {
  spec="$1"; shift
  expec="$1"; shift

  real="$(gosu "$spec" id -u):$(gosu "$spec" id -g):$(gosu "$spec" id -G)"
  [ "$expec" = "$real" ]

  expec="$1"; shift

  # have to "|| true" this one because of "id: unknown ID 1000" (rightfully) having a nonzero exit code
  real="$(gosu "$spec" id -un):$(gosu "$spec" id -gn):$(gosu "$spec" id -Gn)" || true
  [ "$expec" = "$real" ]
}

id

gosut 0 "0:0:$(id -G root)" "root:root:$(id -Gn root)"
gosut 0:0 '0:0:0' 'root:root:root'
gosut root "0:0:$(id -G root)" "root:root:$(id -Gn root)"
gosut 0:root '0:0:0' 'root:root:root'
gosut root:0 '0:0:0' 'root:root:root'
gosut root:root '0:0:0' 'root:root:root'
gosut 1000 "1000:$(id -g):$(id -g)" "1000:$(id -gn):$(id -gn)"
gosut 0:1000 '0:1000:1000' 'root:1000:1000'
gosut 1000:1000 '1000:1000:1000' '1000:1000:1000'
gosut root:1000 '0:1000:1000' 'root:1000:1000'
gosut 1000:root '1000:0:0' '1000:root:root'
gosut 1000:daemon "1000:$(id -g daemon):$(id -g daemon)" '1000:daemon:daemon'
gosut games "$(id -u games):$(id -g games):$(id -G games)" 'games:games:games users'
gosut games:daemon "$(id -u games):$(id -g daemon):$(id -g daemon)" 'games:daemon:daemon'

gosut 0: "0:0:$(id -G root)" "root:root:$(id -Gn root)"
gosut '' "$(id -u):$(id -g):$(id -G)" "$(id -un):$(id -gn):$(id -Gn)"
gosut ':0' "$(id -u):0:0" "$(id -un):root:root"

[ "$(gosu 0 env | grep '^HOME=')" = 'HOME=/root' ]
[ "$(gosu 0:0 env | grep '^HOME=')" = 'HOME=/root' ]
[ "$(gosu root env | grep '^HOME=')" = 'HOME=/root' ]
[ "$(gosu 0:root env | grep '^HOME=')" = 'HOME=/root' ]
[ "$(gosu root:0 env | grep '^HOME=')" = 'HOME=/root' ]
[ "$(gosu root:root env | grep '^HOME=')" = 'HOME=/root' ]
[ "$(gosu 0:1000 env | grep '^HOME=')" = 'HOME=/root' ]
[ "$(gosu root:1000 env | grep '^HOME=')" = 'HOME=/root' ]
[ "$(gosu 1000 env | grep '^HOME=')" = 'HOME=/' ]
[ "$(gosu 1000:0 env | grep '^HOME=')" = 'HOME=/' ]
[ "$(gosu 1000:root env | grep '^HOME=')" = 'HOME=/' ]
[ "$(gosu games env | grep '^HOME=')" = 'HOME=/usr/games' ]
[ "$(gosu games:daemon env | grep '^HOME=')" = 'HOME=/usr/games' ]

# make sure we error out properly in unexpected cases like an invalid username
! gosu bogus true
! gosu 0day true
! gosu 0:bogus true
! gosu 0:0day true
