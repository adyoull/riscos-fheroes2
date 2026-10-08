#!/bin/bash
# Host tests of the RISC OS SDL_mixer build (patches/sdl2_mixer), with
# AddressSanitizer and UBSan, configured like build/build-deps.sh:
#   - test_mixer_midisynth: the midisynth MIDI decoder;
#   - test_mixer_formats: Ogg Vorbis, MP3 and FLAC in the same program as
#     midisynth (its stb_vorbis must not clash with SDL_mixer's renamed one).
# Needs: gcc, libsdl2-dev, python3, ffmpeg (for the tone files) and a
# riscos-midisynth checkout (MIDISYNTH_SRC, default src/riscos-midisynth-*).
#   tests/mixer-midisynth/run.sh
set -e -o pipefail
. "$(dirname "$0")/../../build/env.sh"
# Host build: the cross pkg-config settings from env.sh must not leak in.
unset PKG_CONFIG_LIBDIR
HERE=$(cd "$(dirname "$0")" && pwd)
MS=${MIDISYNTH_SRC:-$SRC/riscos-midisynth-$MIDISYNTH_VERSION}
T=$(mktemp -d)
make -s -C "$MS" host >/dev/null
tar xzf "$DL/SDL2_mixer-$MIXER_VERSION.tar.gz" -C "$T"
( cd "$T/SDL2_mixer-$MIXER_VERSION"
  for p in "$RFH_ROOT"/patches/sdl2_mixer/*.patch; do patch -p1 -s < "$p"; done
  CC=gcc CFLAGS="-O1 -g -DMUSIC_MID -DMUSIC_MID_MIDISYNTH -DSDL_MIXER_RENAME_STB_VORBIS -I$MS/include -fsanitize=address,undefined" \
    ./configure --disable-shared --enable-static --prefix="$T/inst" --enable-music-wave \
      --enable-music-ogg --enable-music-ogg-stb --disable-music-ogg-vorbis --disable-music-ogg-tremor \
      --enable-music-mp3 --enable-music-mp3-drmp3 --disable-music-mp3-mpg123 \
      --enable-music-flac --enable-music-flac-drflac --disable-music-flac-libflac \
      --disable-music-cmd --disable-music-mod --disable-music-midi --disable-music-opus >/dev/null
  make -s -j"$JOBS" build/libSDL2_mixer.la >/dev/null 2>&1
  make -s install-hdrs install-lib >/dev/null 2>&1 )
python3 "$MS/tests/mktestfiles.py" "$T/files" >/dev/null
for f in ogg mp3 flac; do
  ffmpeg -loglevel error -f lavfi -i "sine=frequency=440:duration=1:sample_rate=44100" -ac 2 "$T/files/tone.$f"
done
LIBS="$T/inst/lib/libSDL2_mixer.a $MS/build/host/libmidisynth.a $(pkg-config --libs sdl2) -lm -lpthread"
for t in test_mixer_midisynth test_mixer_formats; do
  gcc -g -fsanitize=address,undefined "$HERE/$t.c" -I"$T/inst/include/SDL2" $(pkg-config --cflags sdl2) $LIBS -o "$T/$t"
  echo "== $t"
  ( cd "$T" && SDL_DISKAUDIOFILE="$T/$t.raw" "./$t" "$T/files" 2>&1 | grep -v CRITICAL )
done
rm -rf "$T"
