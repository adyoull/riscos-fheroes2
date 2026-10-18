## fheroes2 1.1.17 for RISC OS (riscos5)

This is the fifth release of [fheroes2](https://github.com/ihhub/fheroes2) for RISC OS 5. fheroes2 is a free re-creation of the Heroes of Might and Magic II engine. The port was tested on a Raspberry Pi 4.

**You need the original game's data.** That means the `DATA` and `MAPS` directories from the GOG or CD version, or from the free demo:
https://archive.org/download/HeroesofMightandMagicIITheSuccessionWars_1020/h2demo.zip

Copy them into `!fheroes2`, or anywhere you like and set `fheroes2$Data` to that directory. This release contains none of the original game.

### What's new in riscos5
- **The icon bar no longer flashes over the game in full screen.** With "Bring icon bar forward automatically" on, scrolling the map down in full screen used to bring the icon bar forward for a moment. Now, while the pointer is over the full-screen game, it stops 2 pixels above the bottom of the screen, so the icon bar stays where it is. The lowest row the pointer reaches counts as the bottom, so the map still scrolls. Shift-F12 still brings the icon bar forward. `*Set SDL$PointerMargin <pixels>` changes the margin (0 turns it off).
- **Pauses can be logged.** With logging on, any time the game stops for more than half a second is logged, with what was going on (autosave, a music track starting, a computer player's turn, the new day, or the desktop or another program). If you see the game pause, please send the log.
- To upgrade, replace the whole application and copy your `DATA`, `MAPS` (and `MUSIC`) across. Settings and saves in `<Choices$Write>.fheroes2` aren't touched.

### What works
- The game runs in a desktop window and switches to full screen with F4. It stays a desktop task the whole time.
- Bigger and scaled resolutions are available in the game's options.
- The game draws its own pointer. The desktop pointer is hidden only while it is over the game window.
- Only what changes on screen is redrawn (since riscos4), which keeps the processor time down.
- Sound effects play through SharedSoundBuffer.
- **Music:** Ogg, MP3 or FLAC tracks (the GOG version's `MUSIC` directory) if you have them; otherwise the original MIDI music, played through the game's own synthesiser (riscos-midisynth with the TimGM6mb SoundFont). `Set fheroes2$AudioRate 22050` in `!Run` halves the music's processor time.
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
- "Resume music where it left off" starts the track again from the beginning.
- Error boxes from other programs can appear over the game in full screen, as over any desktop window.

### Files
- `fheroes2-1.1.17-riscos5.zip`: the application.
- **Source** (GPL corresponding source, together with this repository's patches and build scripts):
  - `fheroes2-1.1.17-source.tar.gz`;
  - `SDL2_mixer-2.6.3.tar.gz`;
  - `riscos-midisynth-0.4.2-source.tar.gz`.
  - SDL2 is riscos-mesa 20.3.5-16 with its full-screen pointer-margin change (riscos-mesa's 20.3.5-17b devkit), and the toolchain is riscos-crossdev 1.3.

### Built with
- riscos-crossdev 1.3 (GCC 10.2), with the UnixLib 5.0.3.3 release.
- riscos-mesa devkit 20.3.5-17b: SDL 2.26 with its RISC OS drivers.
- SDL2_mixer 2.6.3 with its bundled Ogg, MP3 and FLAC decoders, and a MIDI decoder for riscos-midisynth 0.4.2.

See CHANGELOG.md for the details and BUILDING.md to build it yourself.

Heroes of Might and Magic is a trademark of its owners. This port isn't connected with them.

Parts of this port were written with the help of an AI assistant.
