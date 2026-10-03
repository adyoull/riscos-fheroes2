#!/bin/bash
# Host test of the SDL_mixer midisynth decoder (patches/sdl2_mixer), with
# AddressSanitizer and UBSan. Needs: gcc, libsdl2-dev, python3, and a
# riscos-midisynth checkout (MIDISYNTH_SRC, default src/riscos-midisynth-*).
#   tests/mixer-midisynth/run.sh
set -e
# Host build: the cross PATH and pkg-config settings from env.sh must not leak in.
. "$(dirname "$0")/../../build/env.sh"
MS=${MIDISYNTH_SRC:-$SRC/riscos-midisynth-$MIDISYNTH_VERSION}
T=$(mktemp -d)
make -s -C "$MS" host >/dev/null
tar xzf "$DL/SDL2_mixer-$MIXER_VERSION.tar.gz" -C "$T"
( cd "$T/SDL2_mixer-$MIXER_VERSION"; unset PKG_CONFIG_LIBDIR
  for p in "$RFH_ROOT"/patches/sdl2_mixer/*.patch; do patch -p1 -s < "$p"; done
  CC=gcc CFLAGS="-O1 -g -DMUSIC_MID -DMUSIC_MID_MIDISYNTH -I$MS/include -fsanitize=address,undefined" \
    ./configure --disable-shared --enable-static --prefix="$T/inst" --disable-music-ogg \
      --disable-music-midi --disable-music-mod --disable-music-flac --disable-music-mp3 \
      --disable-music-opus --disable-music-cmd >/dev/null
  make -s -j"$JOBS" build/libSDL2_mixer.la >/dev/null 2>&1
  make -s install-hdrs install-lib >/dev/null 2>&1 )
python3 "$MS/tests/mktestfiles.py" "$T/files" >/dev/null
gcc -g -fsanitize=address,undefined "$(dirname "$0")/test_mixer_midisynth.c" -I"$T/inst/include/SDL2" \
  $(env -u PKG_CONFIG_LIBDIR pkg-config --cflags sdl2) "$T/inst/lib/libSDL2_mixer.a" "$MS/build/host/libmidisynth.a" \
  $(env -u PKG_CONFIG_LIBDIR pkg-config --libs sdl2) -lm -lpthread -o "$T/test"
( cd "$T" && SDL_DISKAUDIOFILE="$T/out.raw" ./test "$T/files" 2>&1 | grep -v CRITICAL )
rm -rf "$T"
