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

# SDL2_mixer: WAV (the game's sound effects), MIDI through midisynth
# (patches/sdl2_mixer/0001), and the music formats fheroes2 looks for in a
# MUSIC directory (the GOG version's tracks): Ogg Vorbis (stb_vorbis), MP3
# (dr_mp3) and FLAC (dr_flac), all bundled in SDL_mixer, no other libraries.
# midisynth has its own stb_vorbis (for .sf3 SoundFonts), so SDL_mixer's is
# renamed (patches/sdl2_mixer/0002, SDL_MIXER_RENAME_STB_VORBIS).
step_mixer() {
  unpack SDL2_mixer-$MIXER_VERSION.tar.gz SDL2_mixer-$MIXER_VERSION sdl2_mixer
  ( cd "$SRC/SDL2_mixer-$MIXER_VERSION"; cross_env
    export CFLAGS="$CFLAGS -DMUSIC_MID -DMUSIC_MID_MIDISYNTH -DSDL_MIXER_RENAME_STB_VORBIS"
    ro_configure --disable-sdltest --enable-music-wave \
      --enable-music-ogg --enable-music-ogg-stb --disable-music-ogg-vorbis --disable-music-ogg-tremor \
      --enable-music-mp3 --enable-music-mp3-drmp3 --disable-music-mp3-mpg123 \
      --enable-music-flac --enable-music-flac-drflac --disable-music-flac-libflac \
      --disable-music-cmd --disable-music-mod --disable-music-midi --disable-music-opus
    # Only the library and headers: the test players (playwave, playmus)
    # would need -lmidisynth after the library.
    make -j"$JOBS" build/libSDL2_mixer.la && make install-hdrs install-lib )
  # The static library needs midisynth after it.
  sed -i 's/^Libs: \(.*\)-lSDL2_mixer/Libs: \1-lSDL2_mixer -lmidisynth/' "$STAGE/lib/pkgconfig/SDL2_mixer.pc"
  for i in MIDISYNTH OGG DRMP3 DRFLAC; do
    "$TARGET-nm" "$STAGE/lib/libSDL2_mixer.a" | grep -q " Mix_MusicInterface_$i\$" \
      || die "SDL2_mixer was built without the $i decoder"
  done
  if "$TARGET-nm" "$STAGE/lib/libSDL2_mixer.a" | grep -q ' T stb_vorbis_'; then
    die "SDL2_mixer's stb_vorbis wasn't renamed (it would clash with midisynth's)"
  fi
}

steps=${*:-midisynth mixer}
for s in $steps; do
  echo "== $s"
  step_$s
done
