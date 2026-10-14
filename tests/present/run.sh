#!/bin/bash
# Host test of the RISC OS present path: tests/present/run.sh [fheroes2 tree]
# The tree defaults to the patched source (build-fheroes2.sh unpack) or work/fheroes2.
set -e -o pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
TREE=${1:-${FH2_TREE:-$ROOT/work/fheroes2}}
[ -f "$TREE/src/engine/riscos_present.h" ] || TREE=$ROOT/src/fheroes2-1.1.17
OUT=${OUT:-$(mktemp -d)}
CXX=${HOST_CXX:-g++}
$CXX -std=c++17 -O1 -g -Wall -Wextra -Werror -fsanitize=address,undefined,alignment -fno-sanitize-recover=all \
  -I"$TREE/src/engine" "$HERE/test_present.cpp" -o "$OUT/test_present"
"$OUT/test_present"
