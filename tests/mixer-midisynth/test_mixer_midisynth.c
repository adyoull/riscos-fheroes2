#include <SDL.h>
#include <SDL_mixer.h>
#include <stdio.h>
#include <stdlib.h>
static volatile int finished = 0;
static void done(void){ finished++; }
static int fail = 0;
#define CHECK(c, m) do { if (!(c)) { printf("FAIL: %s (%s)\n", m, Mix_GetError()); fail = 1; } else printf("ok: %s\n", m); } while (0)
int main(int argc, char **argv) {
    const char *dir = argv[1];
    setvbuf(stdout, NULL, _IONBF, 0);
    char p[512];
    SDL_setenv("SDL_AUDIODRIVER", "disk", 1);
    if (!SDL_getenv("SDL_DISKAUDIOFILE")) SDL_setenv("SDL_DISKAUDIOFILE", "out.raw", 1);
    
    CHECK(SDL_Init(SDL_INIT_AUDIO) == 0, "SDL_Init");
    snprintf(p, sizeof p, "%s/test.sf2", dir);
    Mix_SetSoundFonts(p);
    CHECK(Mix_OpenAudio(44100, AUDIO_S16SYS, 2, 4096) == 0, "open");
    CHECK((Mix_Init(MIX_INIT_MID) & MIX_INIT_MID) != 0, "Mix_Init MID");
    int n = Mix_GetNumMusicDecoders(), found = 0;
    for (int i = 0; i < n; ++i) if (!strcmp(Mix_GetMusicDecoder(i), "MIDISYNTH")) found = 1;
    CHECK(found, "MIDISYNTH decoder listed");
    Mix_HookMusicFinished(done);
    snprintf(p, sizeof p, "%s/bad-random.mid", dir);
    Mix_Music *bad = Mix_LoadMUS(p);
    CHECK(bad == NULL, "bad MIDI refused");
    snprintf(p, sizeof p, "%s/song.mid", dir);
    Mix_Music *m = Mix_LoadMUS(p);
    CHECK(m != NULL, "load song.mid");
    CHECK(Mix_GetMusicType(m) == MUS_MID, "type MUS_MID");
    CHECK(Mix_FadeInMusicPos(m, 0, 100, 5.0) != 0, "seek to 5 s refused");
    Uint32 t0 = SDL_GetTicks();
    CHECK(Mix_FadeInMusic(m, 2, 100) == 0, "play twice");
    while (!finished && SDL_GetTicks() - t0 < 60000) SDL_Delay(10);
    Uint32 t1 = SDL_GetTicks() - t0;
    printf("played twice in %u ms, finished=%d\n", t1, finished);
    CHECK(finished == 1, "finished hook once");
    /* Second object: play, pause, resume, halt */
    Mix_Music *m2 = Mix_LoadMUS(p);
    CHECK(Mix_PlayMusic(m2, -1) == 0, "loop for ever");
    SDL_Delay(300); Mix_PauseMusic(); SDL_Delay(200); Mix_ResumeMusic(); SDL_Delay(300);
    CHECK(Mix_PlayingMusic(), "still playing");
    Mix_VolumeMusic(32);
    SDL_Delay(200);
    printf("tell %.2f\n", Mix_GetMusicPosition(m2));
    Mix_HaltMusic();
    CHECK(!Mix_PlayingMusic(), "halted");
    Mix_FreeMusic(m); Mix_FreeMusic(m2);
    /* free a playing music */
    Mix_Music *m3 = Mix_LoadMUS(p); Mix_PlayMusic(m3, -1); SDL_Delay(100); Mix_FreeMusic(m3);
    CHECK(!Mix_PlayingMusic(), "free while playing");
    Mix_CloseAudio(); SDL_Quit();
    return fail;
}
