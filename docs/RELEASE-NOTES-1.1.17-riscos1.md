## fheroes2 1.1.17 for RISC OS (riscos1)

This is the first release of [fheroes2](https://github.com/ihhub/fheroes2) for RISC OS 5. fheroes2 is a free re-creation of the Heroes of Might and Magic II engine. The port was tested on a Raspberry Pi 4.

**You need the original game's data.** That means the `DATA` and `MAPS` directories from the GOG or CD version, or from the free demo:
https://archive.org/download/HeroesofMightandMagicIITheSuccessionWars_1020/h2demo.zip

Copy them into `!fheroes2`, or anywhere you like and set `fheroes2$Data` to that directory. This release contains none of the original game.

### What works
- The game runs in a desktop window and switches to full screen with F4. It stays a desktop task the whole time.
- Bigger and scaled resolutions are available in the game's options.
- The game draws its own pointer. The desktop pointer is hidden only while it is over the game window.
- Sound effects play through SharedSoundBuffer.
- **Music:** the original MIDI music plays through the game's own synthesiser, riscos-midisynth with the TimGM6mb SoundFont, because RISC OS has none.
- Settings and saved games go in `<Choices$Write>.fheroes2`.
- The translations included with fheroes2 are there, and so are the maps made with its editor.

### Requirements
- RISC OS 5 on an ARMv7 machine (Raspberry Pi 2 or later recommended).
- The ARMEABISupport module and SharedUnixLibrary 1.16 or later, both from !PackMan.
- **For sound:** SharedSoundBuffer and StreamManager, in ssb.zip from https://orac.co.uk/software/rdpclient/rdpclient.html. Merge its `!System` with yours.
  - John Duffell's own site has more details: https://web.archive.org/web/20110920080106/http://www.duffell.riscos.me.uk/
  - SharedSound is part of RISC OS.
- PThreadTicker 0.03 is included.

### Known limitations
- The GOG version's OGG music tracks aren't supported yet; the MIDI music plays instead.
- "Resume music where it left off" starts the track again from the beginning.

### Files
- `fheroes2-1.1.17-riscos1.zip`: the application.
- **Source** (GPL corresponding source, together with this repository's patches and build scripts):
  - `fheroes2-1.1.17-source.tar.gz`;
  - `SDL2_mixer-2.6.3.tar.gz`;
  - `riscos-midisynth-0.4.2-source.tar.gz`.
  - SDL2 is in the riscos-mesa 20.3.5-12 release, and the toolchain is riscos-crossdev 1.3.

### Built with
- riscos-crossdev 1.3: GCC 10.2 and UnixLib 5.0.3.2.
- riscos-mesa devkit 20.3.5-12: SDL 2.26 with its RISC OS drivers.
- SDL2_mixer 2.6.3 with a MIDI decoder for riscos-midisynth 0.4.2.

See CHANGELOG.md for the details and BUILDING.md to build it yourself.

Heroes of Might and Magic is a trademark of its owners. This port isn't connected with them.

Parts of this port were written with the help of an AI assistant.
