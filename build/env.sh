# Shared settings for the riscos-fheroes2 build scripts. Source it:
#   . build/env.sh
#
# Everything can be overridden from the environment before sourcing.
#   GCCSDK_ENV  cross toolchain: riscos-crossdev 1.2 (GCC 10.2, UnixLib 5.0.3.1)
#   DEVKIT      unpacked riscos-mesa devkit (SDL2 with the RISC OS driver, zlib)
#   DL          source tarballs (see build/SHA256SUMS.txt)
#   SRC         where sources are unpacked and patched
#   STAGE       cross-built libraries and headers (--prefix for the deps)
#   JOBS        make parallelism

RFH_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

: "${GCCSDK_ENV:=/opt/rx/riscos-crossdev-toolchain-1.2-x86_64-linux}"
: "${DEVKIT:=/opt/dk/riscos-mesa-devkit-12a}"
: "${DL:=$RFH_ROOT/dl}"
: "${SRC:=$RFH_ROOT/src}"
: "${STAGE:=$RFH_ROOT/stage}"
: "${JOBS:=$(nproc)}"

FHEROES2_VERSION=1.1.17
RISCOS_REL=riscos1test
MIXER_VERSION=2.6.3
MIDISYNTH_VERSION=0.4.2

TARGET=arm-riscos-gnueabihf
BUILD=$(gcc -dumpmachine)

for v in GCCSDK_ENV DEVKIT SRC STAGE; do
  case ${!v} in *" "*) echo "env.sh: $v contains a space: ${!v}" >&2; return 1 2>/dev/null || exit 1 ;; esac
done

export PATH="$GCCSDK_ENV/bin:$PATH"

# VFPv3 without NEON (every ARMv7 RISC OS machine), tuned for the Pi 4.
# -fstack-clash-protection: ARMEABISupport maps the stack a page at a time,
# so frames over 4 KB must probe it (tools/check-stack-probes.py).
RO_CFLAGS="-O2 -mfpu=vfpv3 -mfloat-abi=hard -mtune=cortex-a72 -fstack-clash-protection"

export PKG_CONFIG_LIBDIR="$STAGE/lib/pkgconfig:$DEVKIT/lib/pkgconfig"
export PKG_CONFIG_PATH=
export PKG_CONFIG_SYSROOT_DIR=

die() { echo "error: $*" >&2; exit 1; }

cross_env() {
  export CC=$TARGET-gcc CXX=$TARGET-g++ AR=$TARGET-ar RANLIB=$TARGET-ranlib \
         STRIP=$TARGET-strip NM=$TARGET-nm LD=$TARGET-ld
  export CFLAGS="$RO_CFLAGS -I$STAGE/include"
  export CXXFLAGS="$RO_CFLAGS -I$STAGE/include"
  export CPPFLAGS="-I$STAGE/include"
  export LDFLAGS="-L$STAGE/lib -static"
}

ro_configure() {
  ./configure --host=$TARGET --build=$BUILD --prefix="$STAGE" \
    --disable-shared --enable-static "$@"
}

# check_sha <file>: compare with build/SHA256SUMS.txt
check_sha() {
  local f=$1 want got
  want=$(awk -v n="$(basename "$f")" '$2==n{print $1}' "$RFH_ROOT/build/SHA256SUMS.txt")
  [ -n "$want" ] || die "$(basename "$f") is not in SHA256SUMS.txt"
  got=$(sha256sum "$f" | cut -d' ' -f1)
  [ "$want" = "$got" ] || die "$(basename "$f"): sha256 $got, expected $want"
}
