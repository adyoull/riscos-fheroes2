# Shared settings for the riscos-fheroes2 build scripts. Source it:
#   . build/env.sh
#
# Everything can be overridden from the environment before sourcing.
#   RISCOS_TOOLCHAIN  riscos-crossdev's toolchain (GCCSDK GCC 10.2, UnixLib
#                     5.0.3.3, static). Set in the riscos-crossdev container
#                     image; otherwise build/prepare-toolchain.sh unpacks the
#                     toolchain tarball into $GCCSDK_ENV
#   GCCSDK_ENV        the toolchain used (default $RISCOS_TOOLCHAIN, else
#                     /opt/rx/riscos-crossdev-toolchain-1.4-x86_64-linux)
#   RISCOS_DEVKIT     a riscos-mesa devkit (SDL2 with the RISC OS driver, zlib),
#                     used only if it is the version .riscos-deps names (the
#                     image's can be older); otherwise the one fetched into
#                     $DEVKIT is used
#   UNIXLIB           optional: a riscos-unixlib release put over the
#                     toolchain's (dl/$UNIXLIB/libunixlib.a, local builds only)
#   DL                downloaded sources (build/fetch.sh; build/SHA256SUMS.txt)
#   SRC               where sources are unpacked and patched
#   STAGE             cross-built libraries and headers (--prefix for the deps)
#   JOBS              make parallelism

RFH_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# A release named in .riscos-deps, without the v.
riscos_dep() {
  awk -v n="$1" '$1 == n || $1 == "adyoull/" n {sub(/^v/, "", $2); print $2}' "$RFH_ROOT/.riscos-deps"
}
MESA_VERSION=$(riscos_dep riscos-mesa)
SOFTMIDI_VERSION=$(riscos_dep riscos-softmidi)
[ -n "$MESA_VERSION" ] && [ -n "$SOFTMIDI_VERSION" ] || { echo "env.sh: .riscos-deps needs riscos-mesa and riscos-softmidi lines" >&2; return 1 2>/dev/null || exit 1; }

: "${RISCOS_TOOLCHAIN:=}"
: "${GCCSDK_ENV:=${RISCOS_TOOLCHAIN:-/opt/rx/riscos-crossdev-toolchain-1.4-x86_64-linux}}"
TOOLCHAIN_TARBALL=riscos-crossdev-toolchain-1.4-x86_64-linux.tar.xz
: "${DL:=$RFH_ROOT/dl}"
: "${SRC:=$RFH_ROOT/src}"
: "${STAGE:=$RFH_ROOT/stage}"
: "${JOBS:=$(nproc)}"
: "${UNIXLIB=}"

# The devkit .riscos-deps names: the given one if it is that version.
MESA_DEVKIT_FILE=riscos-mesa-devkit-$MESA_VERSION.tgz
MESA_DEVKIT_URL=https://github.com/adyoull/riscos-mesa/releases/download/v$MESA_VERSION/$MESA_DEVKIT_FILE
if [ -z "${DEVKIT:-}" ]; then
  if [ -n "${RISCOS_DEVKIT:-}" ] && [ "$(cat "$RISCOS_DEVKIT/VERSION" 2>/dev/null)" = "riscos-mesa devkit $MESA_VERSION" ]; then
    DEVKIT=$RISCOS_DEVKIT
  else
    DEVKIT=$RFH_ROOT/devkit/riscos-mesa-devkit-$MESA_VERSION
  fi
fi

# riscos-softmidi (the library is still called midisynth): its source, and its
# release zip for the TimGM6mb SoundFont and that SoundFont's licence.
SOFTMIDI_TARBALL=riscos-softmidi-$SOFTMIDI_VERSION.tar.gz
SOFTMIDI_ZIP=SoftMIDI-$SOFTMIDI_VERSION.zip
# TimGM6mb 1.3 (6 MB, GPL 2), the SoundFont in that zip.
TIMGM6MB_SHA256=c5378b62028c920cb11e4803327983fee2f2cdff5dc89c708e39da417e51c854

FHEROES2_VERSION=1.1.17
RISCOS_REL=riscos12test
MIXER_VERSION=2.6.3

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
