#!/bin/bash
# Set up the cross toolchain and the devkit:
#   1. unpack riscos-crossdev's prebuilt toolchain (1.3: GCC 10.2, UnixLib
#      5.0.3.2, PThreadTicker 0.03) into $GCCSDK_ENV;
#   2. delete libtool .la files: they hold the build machine's absolute
#      paths, which break libtool links once the toolchain has moved;
#   3. delete any shared libraries (static only), except libgcc_s, which
#      libtool's own test links ask for (1.3 has none: it is static only);
#   4. unpack the riscos-mesa devkit into $DEVKIT.
# Needs in $DL: $(basename $GCCSDK_ENV).tar.xz and $(basename $DEVKIT).tgz
# (both in build/SHA256SUMS.txt; see build/env.sh for the versions).
set -e
. "$(dirname "$0")/env.sh"

TC=$(basename "$GCCSDK_ENV")
check_sha "$DL/$TC.tar.xz"
parent=$(dirname "$GCCSDK_ENV")
mkdir -p "$parent"
rm -rf "$GCCSDK_ENV"
tar xJf "$DL/$TC.tar.xz" -C "$parent"
[ "$parent/$TC" = "$GCCSDK_ENV" ] || ln -sfn "$parent/$TC" "$GCCSDK_ENV"

T=$GCCSDK_ENV/arm-riscos-gnueabihf
find -L "$GCCSDK_ENV/" -name '*.la' -delete
find -L "$T/lib" -maxdepth 1 -name '*.so*' ! -name 'libgcc_s.so*' -delete
echo "toolchain ready: $($TARGET-gcc --version | head -1)"

DK=$(basename "$DEVKIT")
check_sha "$DL/$DK.tgz"
mkdir -p "$(dirname "$DEVKIT")"
rm -rf "$DEVKIT"
tar xzf "$DL/$DK.tgz" -C "$(dirname "$DEVKIT")"
echo "devkit ready: $(cat "$DEVKIT/VERSION")"
