#!/bin/bash
# Download what the build needs into $DL, unless it's already there, and
# check everything against build/SHA256SUMS.txt:
#   fheroes2 1.1.17 (GitHub's archive of the tag), SDL2_mixer 2.6.3, the
#   riscos-softmidi source and release zip, and the riscos-mesa devkit that
#   .riscos-deps names (only if $DEVKIT isn't that devkit already).
# Then unpacks that devkit into $DEVKIT.
#   build/fetch.sh
# The toolchain isn't fetched: the riscos-crossdev image has it
# ($RISCOS_TOOLCHAIN), and build/prepare-toolchain.sh unpacks the tarball
# from $DL for a build outside the image. h2demo.zip (host tests only) isn't
# fetched either.
set -euo pipefail
. "$(dirname "$0")/env.sh"
mkdir -p "$DL"

GH=https://github.com
declare -A URL=(
  [fheroes2-$FHEROES2_VERSION.tar.gz]=$GH/ihhub/fheroes2/archive/refs/tags/$FHEROES2_VERSION.tar.gz
  [SDL2_mixer-$MIXER_VERSION.tar.gz]=$GH/libsdl-org/SDL_mixer/releases/download/release-$MIXER_VERSION/SDL2_mixer-$MIXER_VERSION.tar.gz
  [$SOFTMIDI_TARBALL]=$GH/adyoull/riscos-softmidi/archive/refs/tags/v$SOFTMIDI_VERSION.tar.gz
  [$SOFTMIDI_ZIP]=$GH/adyoull/riscos-softmidi/releases/download/v$SOFTMIDI_VERSION/$SOFTMIDI_ZIP
)
if [ "$(cat "$DEVKIT/VERSION" 2>/dev/null)" != "riscos-mesa devkit $MESA_VERSION" ]; then
  URL[$MESA_DEVKIT_FILE]=$MESA_DEVKIT_URL
fi

for f in "${!URL[@]}"; do
  if [ ! -f "$DL/$f" ]; then
    echo "fetching $f"
    curl -fsSL --retry 3 -o "$DL/$f.part" "${URL[$f]}"
    mv "$DL/$f.part" "$DL/$f"
  fi
  check_sha "$DL/$f"
done

if [ -n "${URL[$MESA_DEVKIT_FILE]:-}" ]; then
  rm -rf "$DEVKIT"
  mkdir -p "$(dirname "$DEVKIT")"
  tar xzf "$DL/$MESA_DEVKIT_FILE" -C "$(dirname "$DEVKIT")"
  [ "$(cat "$DEVKIT/VERSION")" = "riscos-mesa devkit $MESA_VERSION" ] \
    || die "$MESA_DEVKIT_FILE didn't unpack to $DEVKIT"
fi
echo "riscos-mesa devkit: $DEVKIT ($(cat "$DEVKIT/VERSION"))"
