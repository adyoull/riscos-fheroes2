# riscos-fheroes2

A port of [fheroes2](https://github.com/ihhub/fheroes2) 1.1.17, the free
re-creation of the Heroes of Might and Magic II engine, to RISC OS 5
(tested on the Raspberry Pi 4).

You need the data of the original game, or of the free demo, to play; see
the application's `!Help`.

## How it's built

- **Toolchain:** [riscos-crossdev](https://github.com/adyoull/riscos-crossdev)
  1.3 (GCCSDK GCC 10.2, PThreadTicker 0.03; static only), with UnixLib
  replaced by the [riscos-unixlib](https://github.com/adyoull/riscos-unixlib)
  5.0.3.3 release.
- **SDL2:** the riscos-mesa devkit 20.3.5-12 (SDL 2.26 with the RISC OS video
  and SharedSoundBuffer sound drivers), used as it is.
- **SDL2_mixer 2.6.3**, WAV and MIDI, with a new decoder that plays MIDI
  through [riscos-midisynth](https://github.com/adyoull/riscos-midisynth)
  0.4.2 (`patches/sdl2_mixer`).
- **fheroes2 1.1.17** with the patches in `patches/fheroes2` (see `series`):

  | Patch | What |
  |---|---|
  | 0001 | Build: `PTHREAD_FLAG` (GCCSDK has no `-pthread`) |
  | 0002 | Settings and saves in `<Choices$Write>.fheroes2`; `fheroes2$Data`; case-insensitive names |
  | 0003 | Draw straight into the window surface (no accelerated renderer); scaling; software cursor |
  | 0004 | Output to `fheroes2$Log`, never the screen; heap in a dynamic area |
  | 0005 | Waits that let the desktop run; 4096-sample audio buffer |

- The program is linked statically and converted to an Absolute (AIF)
  file with elf2aif, so `!SharedLibs` isn't needed.

See [BUILDING.md](BUILDING.md) for the steps and checks, and
[CHANGELOG.md](CHANGELOG.md) for what changed in each build.

## Licence

fheroes2 is GPL 2 or later, and so is this port's work on it (see COPYING). The build
scripts and tools are under the same licence. SDL2 and SDL2_mixer are
zlib-licensed, riscos-midisynth and TinySoundFont MIT, the TimGM6mb
SoundFont GPL 2. The application's `docs.licences` has every notice.

Heroes of Might and Magic is a trademark of its owners. This port isn't
connected with them and doesn't include any of the original game.

Parts of this port were written with the help of an AI assistant.
