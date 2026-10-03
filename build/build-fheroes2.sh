#!/bin/bash
# Cross-build fheroes2 for RISC OS.
#
#   build/build-fheroes2.sh [unpack]   unpack: fresh tree from $DL + patches/fheroes2 first
#
# The tree is $SRC/fheroes2-$FHEROES2_VERSION (FH2_TREE overrides, e.g. the
# git work tree in work/fheroes2 while editing patches). Uses upstream's
# plain Makefiles (src/dist), PLATFORM=all. Result: <tree>/src/dist/fheroes2/fheroes2
# (an unstripped ELF; package.sh strips it and makes the AIF).
set -e
. "$(dirname "$0")/env.sh"

TREE=${FH2_TREE:-$SRC/fheroes2-$FHEROES2_VERSION}

if [ "${1:-}" = unpack ]; then
  check_sha "$DL/fheroes2-$FHEROES2_VERSION.tar.gz"
  rm -rf "$TREE"
  mkdir -p "$SRC"
  tar xzf "$DL/fheroes2-$FHEROES2_VERSION.tar.gz" -C "$SRC"
  while read -r p; do
    case $p in ""|"#"*) continue ;; esac
    echo "  patch $p"
    patch -d "$TREE" -p1 -s < "$RFH_ROOT/patches/fheroes2/$p" || die "$p doesn't apply"
  done < "$RFH_ROOT/patches/fheroes2/series"
fi
[ -d "$TREE/src/dist" ] || die "no fheroes2 tree at $TREE (run with 'unpack')"

SDL_FLAGS=$(pkg-config --cflags SDL2_mixer sdl2)
SDL_LIBS=$(pkg-config --libs SDL2_mixer sdl2)

# -ffile-prefix-map: no build paths in the binary (__FILE__ in asserts).
# -DNDEBUG: release build, as upstream's CMake release configuration.
# The flags go in the environment, not on the make command line, because
# the Makefiles append their own (-std=c++17, warnings) to them.
CFLAGS="$RO_CFLAGS" \
CXXFLAGS="$RO_CFLAGS -ffile-prefix-map=$TREE=fheroes2-$FHEROES2_VERSION" \
CPPFLAGS="-DNDEBUG" \
LDFLAGS="-static -L$STAGE/lib" \
PTHREAD_FLAG= \
make -C "$TREE/src/dist" -j"$JOBS" PLATFORM=all \
  CC=$TARGET-gcc CXX=$TARGET-g++ AR=$TARGET-ar \
  SDL_FLAGS="$SDL_FLAGS" SDL_LIBS="$SDL_LIBS"
ls -l "$TREE/src/dist/fheroes2/fheroes2"
