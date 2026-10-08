/* Host test: the music formats the RISC OS SDL_mixer build enables (Ogg
   Vorbis, MP3, FLAC) load and play in the same program as the midisynth
   MIDI decoder, whose own stb_vorbis must not clash with SDL_mixer's
   (patches/sdl2_mixer/0002). Each file is a short 440 Hz tone; the test
   checks the type, plays it once to the end and checks the output isn't
   silent.   test_mixer_formats <dir with tone.ogg, tone.mp3, tone.flac> */
#include <SDL.h>
#include <SDL_mixer.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static volatile int finished = 0;
static void done(void) { finished = 1; }
static int fail = 0;
#define CHECK(c, m) do { if (!(c)) { printf("FAIL: %s (%s)\n", m, Mix_GetError()); fail = 1; } else printf("ok: %s\n", m); } while (0)

static long peak_since(FILE *f, long from)
{
    long peak = 0;
    short s;
    fseek(f, from, SEEK_SET);
    while (fread(&s, sizeof s, 1, f) == 1) {
        long a = s < 0 ? -(long)s : s;
        if (a > peak) peak = a;
    }
    return peak;
}

int main(int argc, char **argv)
{
    static const struct { const char *name; Mix_MusicType type; const char *decoder; } files[] = {
        { "tone.ogg", MUS_OGG, "OGG" },
        { "tone.mp3", MUS_MP3, "DRMP3" },
        { "tone.flac", MUS_FLAC, "DRFLAC" },
    };
    const char *out;
    char p[512];
    FILE *f;
    int i, n, flags;

    setvbuf(stdout, NULL, _IONBF, 0);
    if (argc < 2) return 2;
    SDL_setenv("SDL_AUDIODRIVER", "disk", 1);
    out = SDL_getenv("SDL_DISKAUDIOFILE");
    if (!out) { out = "out-formats.raw"; SDL_setenv("SDL_DISKAUDIOFILE", out, 1); }
    CHECK(SDL_Init(SDL_INIT_AUDIO) == 0, "SDL_Init");
    flags = Mix_Init(MIX_INIT_OGG | MIX_INIT_MP3 | MIX_INIT_FLAC | MIX_INIT_MID);
    CHECK(Mix_OpenAudio(44100, AUDIO_S16SYS, 2, 4096) == 0, "open");
    flags = Mix_Init(MIX_INIT_OGG | MIX_INIT_MP3 | MIX_INIT_FLAC | MIX_INIT_MID);
    CHECK(flags & MIX_INIT_OGG, "Mix_Init OGG");
    CHECK(flags & MIX_INIT_MP3, "Mix_Init MP3");
    CHECK(flags & MIX_INIT_FLAC, "Mix_Init FLAC");
    CHECK(flags & MIX_INIT_MID, "Mix_Init MID (midisynth, same program)");
    n = Mix_GetNumMusicDecoders();
    for (i = 0; i < (int)(sizeof files / sizeof files[0]); ++i) {
        int j, found = 0;
        for (j = 0; j < n; ++j) if (!strcmp(Mix_GetMusicDecoder(j), files[i].decoder)) found = 1;
        snprintf(p, sizeof p, "decoder %s listed", files[i].decoder);
        CHECK(found, p);
    }
    Mix_HookMusicFinished(done);
    f = fopen(out, "rb");
    for (i = 0; i < (int)(sizeof files / sizeof files[0]); ++i) {
        Mix_Music *m;
        long before;
        Uint32 t0;
        char msg[128];
        snprintf(p, sizeof p, "%s/%s", argv[1], files[i].name);
        m = Mix_LoadMUS(p);
        snprintf(msg, sizeof msg, "load %s", files[i].name); CHECK(m != NULL, msg);
        if (!m) continue;
        snprintf(msg, sizeof msg, "%s type", files[i].name); CHECK(Mix_GetMusicType(m) == files[i].type, msg);
        if (f) { fseek(f, 0, SEEK_END); before = ftell(f); } else before = 0;
        finished = 0;
        t0 = SDL_GetTicks();
        snprintf(msg, sizeof msg, "play %s", files[i].name); CHECK(Mix_PlayMusic(m, 1) == 0, msg);
        while (!finished && SDL_GetTicks() - t0 < 20000) SDL_Delay(10);
        snprintf(msg, sizeof msg, "%s finished in %u ms", files[i].name, (unsigned)(SDL_GetTicks() - t0));
        CHECK(finished, msg);
        SDL_Delay(200);
        if (!f) f = fopen(out, "rb");
        if (f) {
            long peak = peak_since(f, before);
            snprintf(msg, sizeof msg, "%s output not silent (peak %ld)", files[i].name, peak);
            CHECK(peak > 1000, msg);
        }
        Mix_FreeMusic(m);
    }
    if (f) fclose(f);
    Mix_CloseAudio();
    Mix_Quit();
    SDL_Quit();
    return fail;
}
