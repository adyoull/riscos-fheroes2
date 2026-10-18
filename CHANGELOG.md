# riscos-fheroes2 changes

## 1.1.17-riscos10test

Diagnostics for a lock-up: a game on the Pi locked up for a long time and
then crashed, and the log said nothing about it, because a stall is only
logged when it ends.

- **Lock-up watchdog** (new patch 0009, with logging on, so in test
  builds). While no check for events has finished for more than 3
  seconds, a separate thread logs every 5 seconds: what the game's main
  thread is doing (game code, checking for events, waiting or drawing),
  the step in progress (autosave, music track, computer player's turn,
  new day), when sound was last mixed, and the heap size. If the game is
  stuck inside another program's turn on the desktop, nothing can be
  logged until that ends.
- Logs from riscos9test showed no stall in the game itself: two pauses
  of exactly 4 seconds were spent in the desktop (another program), and
  computer players' turns take up to 2.8 seconds.

## 1.1.17-riscos5 (tag `v1.1.17-riscos5`)

The riscos9test build, tested on a Pi and released, with logging off by
default (remove the `|` in front of `Set fheroes2$LogOn 1` in `!Run` to
get a log, which also has the drawing times and any stalls).

## 1.1.17-riscos9test

- Linked with the riscos-mesa **test** devkit **20.3.5-17b** (was the
  20.3.5-12 release): 20.3.5-16 plus riscos-mesa's fix for the icon bar
  flashing over the game in full screen with "Bring icon bar forward
  automatically" (reported on riscos4). While the pointer is over the
  full-screen game it stops 2 pixels above the bottom of the screen, so
  the Wimp no longer brings the icon bar forward; the lowest row it can
  reach counts as the bottom row, so the map still scrolls. Shift-F12
  still brings the icon bar forward. `*Set SDL$PointerMargin <pixels>`
  changes the margin (0 turns it off). Not tried on a Pi yet.
- The stall log from riscos8test stays (test builds log by default).

## 1.1.17-riscos8test

Diagnostics for a reported pause: "sometimes, no more than once every 10
to 20 minutes, the game completely stops for 2 to 3 seconds, then starts
again" (Pi, riscos4).

- **Stalls are logged** (new patch 0008; test builds log by default).
  When the game stops for more than half a second the log says how:
  - "the game ran N ms without checking for events": the game itself was
    busy, so nothing else on the desktop ran either, with the step in
    progress or just finished (saving the autosave, starting a music
    track, a computer player's turn, the new day);
  - "checking for events took N ms" or "a wait of N ms took M ms": the
    desktop or another program held the computer;
  - "Slow step: ... took N ms" for any of those steps over 300 ms.
  Each line, and the drawing times every 10 seconds, has the heap's size,
  to see whether a pause comes with the heap growing.
- The icon bar showing over the game in full screen when the pointer
  reaches the bottom of the screen (with "Bring icon bar forward
  automatically") belongs to the SDL driver and has been passed to
  riscos-mesa.

## 1.1.17-riscos4 (tag `v1.1.17-riscos4`)

The riscos7test build, released, with logging off by default (remove the
`|` in front of `Set fheroes2$LogOn 1` in `!Run` to get a log, which
also has the drawing times).

## 1.1.17-riscos7test

Faster drawing, mostly for the Pi: the game's 8-bit screen is converted
into the window (or the screen) only where it changed.

- **Only what changed is drawn** (new patch 0006, `riscos_present.h`).
  Converting the game screen to the desktop's colours, and plotting it,
  cost more than the game's own drawing. The colour cycling (water, lava:
  17 colours every 220 ms) made every cycle redraw the whole screen, even
  in menus with no water.
  - A copy of the last frame is kept; only pixels that differ from it are
    converted, and only the 64 x 16 pixel cells that changed are plotted.
  - A colour cycle redraws only pixels in the cycling colours.
  - Scaled pictures are never read back from the screen; the black
    borders are filled only when the size changes.
  - In full screen everything is redrawn every 5 seconds anyway, in case
    another program drew over the screen.
  - Replaying 880 frames recorded from a game on the adventure map
    (1024 x 768): per frame 35,000 pixels converted instead of 1.1
    million and 63,000 plotted instead of 742,000 in a 1:1 window
    (scaled x2: 139,000 instead of 4.4 million converted), with the
    same picture every frame. Not yet timed on a Pi.
- **The time spent drawing is logged** (with logging on, so in test
  builds): every 10 seconds, the frames, milliseconds per frame
  converting and plotting, and the pixels and rectangles per frame.
- **`fheroes2$AudioRate`** (new patch 0007): `Set fheroes2$AudioRate
  22050` (in `!Run`, commented out) mixes the sound at 22050 Hz instead
  of 44100. The MIDI music then takes about half the processor time; the
  sound effects are 22050 Hz anyway.
- **Compiled with -O3**, upstream's own setting (the -O2 for the RISC OS
  build used to override it).
- New host tests: `tests/present/run.sh` (ASan/UBSan, mutation-checked)
  and `tests/present/bench.cpp`.

## 1.1.17-riscos3 (tag `v1.1.17-riscos3`)

The riscos6test build, released, with logging off by default (remove the
`|` in front of `Set fheroes2$LogOn 1` in `!Run` to get a log).

## 1.1.17-riscos6test

- **Ogg Vorbis, MP3 and FLAC music.** fheroes2 plays music tracks from a
  `MUSIC` directory when it finds them (the GOG version's tracks are Ogg
  Vorbis); until now this build had none of these formats. If such a
  track was found but couldn't be played, that piece of music was simply
  silent. SDL2_mixer now has its bundled decoders turned on: stb_vorbis
  (Ogg), dr_mp3 and dr_flac. No other libraries are needed.
- SDL_mixer's stb_vorbis and riscos-midisynth's own copy (for .sf3
  SoundFonts) had the same function names, so the program couldn't link
  both. New `patches/sdl2_mixer/0002` gives SDL_mixer's copy `Mix_`
  names when built with `SDL_MIXER_RENAME_STB_VORBIS`. `build-deps.sh`
  stops if a decoder is missing or the names clash.
- Host tests: `tests/mixer-midisynth/run.sh` now also plays an Ogg, an MP3
  and a FLAC file in the same program as midisynth (ASan/UBSan, with the
  alignment check).
- Test builds log by default again (`package.sh` turns logging on in
  `!Run` for any `*test` version); releases still don't.

## 1.1.17-riscos2 (tag `v1.1.17-riscos2`)

- Relinked with **UnixLib 5.0.3.3**, the latest riscos-unixlib release (was
  5.0.3.2). Its fixes are in threads waiting inside read/write and stdio,
  fork with threads, the services database, heap areas after a small
  gap, /dev/dsp on DigitalRenderer, swprintf and exit codes. fheroes2 is a
  threaded program, so the thread fixes are the ones that matter here.
  No change to the game's own code; PThreadTicker stays 0.03.
- riscos-crossdev 1.3 still ships 5.0.3.2, so `prepare-toolchain.sh` puts
  the 5.0.3.3 library over it (`UNIXLIB` in `build/env.sh`). The public
  headers of the two releases are identical.

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
