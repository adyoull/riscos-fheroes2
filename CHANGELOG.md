# riscos-fheroes2 changes

## 1.1.17-riscos2test (unreleased)

- Escape (and any other key) acted several times per press: the quit
  dialog flashed up and closed again. SDL's RISC OS driver sends another
  key-down for every key still held each time the game polls; those
  repeats are now only accepted at the desktop's own auto-repeat delay and
  rate (*Configure Delay/Repeat) (new patch 0006). The proper fix belongs
  in the SDL driver and has been passed to riscos-mesa.

## 1.1.17-riscos1test (first test build)

First RISC OS build of fheroes2 1.1.17, for testing on a Raspberry Pi.

- Built with riscos-crossdev 1.2 (GCC 10.2, UnixLib 5.0.3.1) and the
  riscos-mesa devkit 12a (SDL2 2.26 with the RISC OS video and sound
  drivers), statically linked, as an Absolute (AIF) file.
- Drawing: RISC OS has no accelerated SDL renderer, so the game's 8-bit
  screen is converted straight into the window, scaled with nearest
  pixels in full screen, and only changed areas are plotted (patch 0003).
- The game draws its own mouse pointer; the desktop pointer is hidden
  only while it is over the window (0003).
- Settings and saves are in `<Choices$Write>.fheroes2`; the game data can
  be inside the application or in the directory named by `fheroes2$Data`
  (0002).
- Nothing is printed in the desktop: output goes to the file named by
  `fheroes2$Log` (test builds set it to `<Wimp$ScrapDir>.fheroes2log`).
  The heap is in a dynamic area, "fheroes2 Heap" (0004).
- Pauses in battles let other desktop programs run, and the sound buffer
  is 4096 samples (0005).
- Music: SDL2_mixer plays MIDI through riscos-midisynth 0.4.2 with the
  TimGM6mb SoundFont (new SDL_mixer decoder, `patches/sdl2_mixer`).
  Ogg music (the GOG version's tracks) isn't supported yet: SDL_mixer's
  and midisynth's copies of stb_vorbis clash.
