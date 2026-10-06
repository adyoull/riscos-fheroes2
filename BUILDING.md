# Building riscos-fheroes2

On an x86_64 Linux machine (tested: Ubuntu 24.04) with `build-essential`,
`autoconf`, `libtool`, `pkg-config`, `gettext`, `gawk`, `python3` and
`python3-pil`.

## Sources

Put these in `dl/` (their SHA-256 sums are in `build/SHA256SUMS.txt`):

| File | From |
|---|---|
| `riscos-crossdev-toolchain-1.3-x86_64-linux.tar.xz` | riscos-crossdev release 1.3 |
| `riscos-mesa-devkit-20.3.5-12.tgz` | riscos-mesa release 20.3.5-12 |
| `unixlib-5.0.3.3/libunixlib.a` | riscos-unixlib release 5.0.3.3 (put over the toolchain's 5.0.3.2 by `prepare-toolchain.sh`) |
| `fheroes2-1.1.17.tar.gz` | `git archive --prefix=fheroes2-1.1.17/` of tag 1.1.17 (2685c21) |
| `SDL2_mixer-2.6.3.tar.gz` | libsdl.org release |
| `riscos-midisynth-0.4.2.tar.gz` | `git archive --prefix=riscos-midisynth-0.4.2/` of riscos-midisynth 0.4.2 (628e4b6) |
| `TimGM6mb.sf2` | TimGM6mb 1.3 (as shipped with !MIDISynth) |
| `h2demo.zip` | the HoMM II demo, for testing only (never shipped) |

## Steps

```sh
build/prepare-toolchain.sh     # toolchain -> /opt/rx/..., devkit -> /opt/dk/...
build/build-deps.sh            # midisynth, SDL2_mixer -> stage/
build/build-fheroes2.sh unpack # fresh tree in src/, patches, build (about 5 min on 2 cores)
build/package.sh               # checks, then dist/!fheroes2 and the zip
```

`GCCSDK_ENV`, `DEVKIT`, `DL`, `SRC`, `STAGE` and `JOBS` can be set before
running (see `build/env.sh`). `build-fheroes2.sh` without `unpack`
rebuilds the existing tree (only what changed).

## Checks (package.sh runs them)

- `tools/check-unixlib.sh`: the program has UnixLib 5.0.3.1+'s 640-byte
  pthread ticker block, consistently.
- `tools/check-stack-probes.py`: every function with a stack frame of
  4 KB or more probes the stack (`-fstack-clash-protection`).
- No `/home/` paths or "claude" in the binary (`-ffile-prefix-map`).

Also worth running after changing code:

- Alignment: RISC OS faults unaligned loads. Compile every file with
  `-fsyntax-only -Wcast-align=strict` (0 warnings for 1.1.17), and run a
  host build with `-fsanitize=alignment` through a game (see below).
- `tests/mixer-midisynth/run.sh`: the SDL_mixer MIDI decoder on the host
  with ASan/UBSan.

## Host test of the RISC OS drawing code

The present path in patch 0003 is RISC OS only. To try it on Linux, copy
the tree, `sed -i 's/defined( __riscos__ )/1/' src/engine/screen.cpp`,
and build with the host compiler:

```sh
CXXFLAGS="-O1 -g -fsanitize=alignment,undefined" LDFLAGS=-fsanitize=alignment,undefined \
  make -C src/dist PLATFORM=all
```

Run it in a directory with `files/data/*.h2d` and the demo's `DATA` and
`MAPS` (e.g. under Xvfb, `HOME` set to a scratch directory). Choose a
scaled resolution such as "640 x 480 (x2.0)" to check scaling and the
mouse mapping.

## Editing the patches

```sh
tools/fh2-patches.sh checkout   # work/fheroes2: git, tag pristine + one commit per patch
# edit, then commit (or amend/fix up the patch's commit)
FH2_TREE=$PWD/work/fheroes2 build/build-fheroes2.sh
tools/fh2-patches.sh export     # -> patches/fheroes2/*.patch and series
tools/fh2-patches.sh check      # the series reproduces the work tree
```

## RISC OS rules for this port

- Nothing may print in the desktop (patch 0004 sends output to a file).
- Never wait without letting the Wimp poll (SDL_Delay does; UnixLib's
  sleep functions don't).
- No popen/system/fork/exec.
- A file can be open for writing only once.
- No unaligned loads or stores.
- SDL2 changes go to riscos-mesa as a handoff; UnixLib changes to the
  UnixLib project.
