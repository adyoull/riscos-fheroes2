#!/bin/bash
# Make the !fheroes2 application and its zip.
#   build/package.sh     -> dist/!fheroes2, dist/fheroes2-$VERSION.zip
# Needs a finished build (build/build-fheroes2.sh). Runs the checks on the
# linked program first (UnixLib ticker block, stack probes, no build paths).
set -e
. "$(dirname "$0")/env.sh"

VERSION=${VERSION:-$FHEROES2_VERSION-$RISCOS_REL}
TREE=${FH2_TREE:-$SRC/fheroes2-$FHEROES2_VERSION}
ELF=$TREE/src/dist/fheroes2/fheroes2
DIST=${DIST:-$RFH_ROOT/dist}
APP=$DIST/'!fheroes2'
[ -x "$ELF" ] || die "build first (build/build-fheroes2.sh)"

# Checks.
FH2_TREE=$TREE "$RFH_ROOT/tools/check-unixlib.sh" "$ELF"
python3 "$RFH_ROOT/tools/check-stack-probes.py" "$ELF" "$TARGET-objdump" | tail -1 | tee /dev/stderr | grep -q ' 0 without stack probes' \
  || die "functions with big stack frames and no probes"
if strings -a "$ELF" | grep -E -i 'claude|/home/' >/dev/null; then die "build paths or names in the binary"; fi

rm -rf "$APP"
mkdir -p "$APP/docs/licences" "$APP/docs/patches" "$APP/files/data" "$APP/files/lang" \
         "$APP/files/soundfonts" "$APP/maps"
cp "$RFH_ROOT"/app/'!fheroes2'/* "$APP/"

# Program: ELF -> AIF (Absolute), stripped. -e: EABI (arm-riscos-gnueabihf) ELF.
$TARGET-strip -o "$STAGE/fheroes2.stripped" "$ELF"
elf2aif -e "$STAGE/fheroes2.stripped" "$APP/fheroes2,ff8" >/dev/null

# PThreadTicker module (riscos-crossdev 1.2 = UnixLib 5.0.3.1's 0.03).
cp "$GCCSDK_ENV/riscos/PThrTicker,ffa" "$APP/PThrTicker,ffa"

# fheroes2's own data: resources, translations, maps made with its editor.
cp "$TREE/files/data/"*.h2d "$APP/files/data/"
make -s -C "$TREE/files/lang" >/dev/null
cp "$TREE/files/lang/"*.mo "$APP/files/lang/"
cp "$TREE/maps/"*.fh2m "$APP/maps/"

# MIDI SoundFont for the music (riscos-midisynth plays it).
check_sha "$DL/TimGM6mb.sf2"
cp "$DL/TimGM6mb.sf2" "$APP/files/soundfonts/TimGM6mb.sf2"

# Docs and licences.
cp "$TREE/LICENSE" "$APP/docs/COPYING,fff"
cp "$TREE/changelog.txt" "$APP/docs/Changes,fff"
cp "$RFH_ROOT/CHANGELOG.md" "$APP/docs/RISCOS-Changes,fff"
lic=$APP/docs/licences
cp "$DEVKIT/LICENCES.txt" "$lic/riscos-mesa-devkit,fff"          # SDL2, zlib, UnixLib
cp "$SRC/SDL2_mixer-$MIXER_VERSION/LICENSE.txt" "$lic/SDL2_mixer,fff"
MS=$SRC/riscos-midisynth-$MIDISYNTH_VERSION
cp "$MS/LICENSE" "$lic/midisynth,fff"
cp "$MS/third_party/TinySoundFont/LICENSE" "$lic/TinySoundFont,fff" 2>/dev/null \
  || sed -n '1,/^\*\//p' "$MS/third_party/TinySoundFont/tsf.h" > "$lic/TinySoundFont,fff"
cp "$MS/app/!MIDISynth/SFLicence,fff" "$lic/TimGM6mb,fff"
cp "$GCCSDK_ENV/riscos/PThreadTicker-Licence,fff" "$lic/PThreadTicker,fff"

# GPL corresponding source: the patches applied to fheroes2 and SDL2_mixer.
for p in "$RFH_ROOT"/patches/fheroes2/*.patch; do
  cp "$p" "$APP/docs/patches/$(basename "$p" .patch | cut -c1-40),fff"
done
for p in "$RFH_ROOT"/patches/sdl2_mixer/*.patch; do
  cp "$p" "$APP/docs/patches/SDL2_mixer-$(basename "$p" .patch | cut -c1-29),fff"
done

# Icon sprites from fheroes2's own icon.
python3 "$RFH_ROOT/tools/png2sprite.py" "$TREE/src/resources/fheroes2.png" "$APP/!Sprites,ff9" \
  '!fheroes2:34x34' 'sm!fheroes2:17x17'

echo "$VERSION" > "$APP/docs/Version,fff"

( cd "$DIST" && rm -f "fheroes2-$VERSION.zip" && python3 "$RFH_ROOT/tools/rozip.py" "fheroes2-$VERSION.zip" '!fheroes2' )
ls -la "$DIST/fheroes2-$VERSION.zip"
md5sum "$DIST/fheroes2-$VERSION.zip" "$APP/fheroes2,ff8"
