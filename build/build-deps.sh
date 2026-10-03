#!/bin/bash
# Cross-build the libraries fheroes2 needs that the riscos-mesa devkit
# doesn't provide, into $STAGE.
#
#   build/build-deps.sh [step...]      steps: midisynth mixer (default: both)
#
# SDL2 and zlib come from the devkit. Each step unpacks a fresh copy from
# $DL (checked against build/SHA256SUMS.txt), so it can be re-run alone.
set -e
. "$(dirname "$0")/env.sh"

mkdir -p "$SRC" "$STAGE/lib/pkgconfig" "$STAGE/include"

# unpack <tarball> <dir> [patch dir]: fresh copy in $SRC, then patches/<name>/*.patch
unpack() {
  local tarball=$1 dir=$2 name=${3:-}
  check_sha "$DL/$tarball"
  rm -rf "$SRC/$dir"
  tar xf "$DL/$tarball" -C "$SRC"
  if [ -n "$name" ] && [ -d "$RFH_ROOT/patches/$name" ]; then
    for p in "$RFH_ROOT"/patches/$name/*.patch; do
      [ -e "$p" ] || continue
      echo "  patch $(basename "$p")"
      patch -d "$SRC/$dir" -p1 -s < "$p" || die "$(basename "$p") doesn't apply"
    done
  fi
}

# riscos-midisynth (TinySoundFont): the MIDI synthesiser for the music.
step_midisynth() {
  unpack riscos-midisynth-$MIDISYNTH_VERSION.tar.gz riscos-midisynth-$MIDISYNTH_VERSION
  make -C "$SRC/riscos-midisynth-$MIDISYNTH_VERSION" \
    CROSS="$GCCSDK_ENV/bin/$TARGET-" \
    RO_CFLAGS="-O3 -ffast-math -mfpu=vfpv3 -mfloat-abi=hard -mtune=cortex-a72 -fstack-clash-protection" \
    GCCSDK_INSTALL_ENV="$STAGE" build/riscos/libmidisynth.a install
}

# SDL2_mixer: WAV (the game's sound effects) and MIDI through midisynth
# (patches/sdl2_mixer). Everything else off. Ogg Vorbis (the GOG version's
# music tracks) is off for now: SDL_mixer's stb_vorbis and the copy inside
# midisynth (for .sf3 SoundFonts) both export the stb_vorbis_* symbols.
step_mixer() {
  unpack SDL2_mixer-$MIXER_VERSION.tar.gz SDL2_mixer-$MIXER_VERSION sdl2_mixer
  ( cd "$SRC/SDL2_mixer-$MIXER_VERSION"; cross_env
    export CFLAGS="$CFLAGS -DMUSIC_MID -DMUSIC_MID_MIDISYNTH"
    ro_configure --disable-sdltest --enable-music-wave --disable-music-ogg \
      --disable-music-cmd --disable-music-mod --disable-music-midi \
      --disable-music-flac --disable-music-mp3 --disable-music-opus
    # Only the library and headers: the test players (playwave, playmus)
    # would need -lmidisynth after the library.
    make -j"$JOBS" build/libSDL2_mixer.la && make install-hdrs install-lib )
  # The static library needs midisynth after it.
  sed -i 's/^Libs: \(.*\)-lSDL2_mixer/Libs: \1-lSDL2_mixer -lmidisynth/' "$STAGE/lib/pkgconfig/SDL2_mixer.pc"
  "$TARGET-nm" "$STAGE/lib/libSDL2_mixer.a" | grep -q 'Mix_MusicInterface_MIDISYNTH' \
    || die "SDL2_mixer was built without the midisynth decoder"
}

steps=${*:-midisynth mixer}
for s in $steps; do
  echo "== $s"
  step_$s
done
