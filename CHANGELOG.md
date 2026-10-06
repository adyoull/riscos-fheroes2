# riscos-fheroes2 changes

## 1.1.17-riscos1 (first release, tag `v1.1.17-riscos1`)

The riscos5test build, released. Changes from riscos5test:

- Logging is off by default (test builds wrote a log every run). To get a
  log, remove the `|` in front of `Set fheroes2$LogOn 1` in `!Run`.
- `!Help` says where to report problems (the GitHub issues page).

## 1.1.17-riscos5test

- Built with the released riscos-mesa devkit **20.3.5-12** instead of the
  interim 12f, so the build can be made from public files. Its SDL code
  is identical to 12f's, so nothing changes when playing.
- riscos-mesa confirmed on the Pi: one key-down per press (Escape opens
  the quit dialog and it stays), title-bar and border clicks no longer
  reach the game, and the pointer row is no longer one out.

## 1.1.17-riscos4test

Relinked with the newest released libraries; the game's own code is
unchanged.

- **riscos-crossdev 1.3:** UnixLib 5.0.3.2 (was 5.0.3.1). Nothing in it is
  needed by fheroes2, but it is the current release; the toolchain is now
  static only. PThreadTicker stays 0.03.
- **riscos-mesa devkit 12f** (was 12e): in a window, the title bar, scroll
  bars and border icons no longer count as the game's area, so dragging
  the window by its title bar or clicking its close or back icon no longer
  clicks or drags inside the game; and mouse positions are no longer one
  row out (clicks landed one pixel lower than drawn).
- fheroes2 1.1.17, SDL2_mixer 2.6.3 and riscos-midisynth 0.4.2 are still
  the latest releases (UnixLib 5.0.3.3 and midisynth 0.4.3 are only
  test versions so far).

## 1.1.17-riscos3test

- Linked with the riscos-mesa devkit 12e, whose SDL driver now sends one
  key-down per press and repeats held keys at the desktop's auto-repeat
  delay and rate (riscos-mesa's fix for the Escape problem below). Patch
  0006, this port's stop-gap for the same thing, is removed.

## 1.1.17-riscos2test

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
