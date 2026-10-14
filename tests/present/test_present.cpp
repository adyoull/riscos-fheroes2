// Host test of the RISC OS present path (src/engine/riscos_present.h, patch 0006).
//
// A random game screen is changed step by step, as the game does: some pixels inside an
// area it reports, colour cycling, other palettes, new sizes. After every step the
// surface, and a "screen" that only receives the rectangles the presenter says to
// plot, must equal a full conversion of the game screen.

#include "riscos_present.h"

#include <cstdio>
#include <cstdlib>
#include <random>

using fheroes2::riscos::Presenter;
using fheroes2::riscos::PresentRect;
using fheroes2::riscos::PresentStats;

namespace
{
    std::mt19937 rng( 12345 );

    int rnd( int n )
    {
        return static_cast<int>( rng() % static_cast<unsigned>( n ) );
    }

    struct Case
    {
        int gw, gh, sw, sh;
        bool keepAspect;
    };

    int failures = 0;

    void fail( const char * what, int step, int x, int y )
    {
        if ( failures < 10 ) {
            std::printf( "FAIL %s at step %d (%d, %d)\n", what, step, x, y );
        }
        ++failures;
    }

    PresentRect fit( int gw, int gh, int sw, int sh )
    {
        PresentRect d;
        if ( static_cast<int64_t>( sw ) * gh <= static_cast<int64_t>( sh ) * gw ) {
            d.w = sw;
            d.h = static_cast<int>( static_cast<int64_t>( sw ) * gh / gw );
        }
        else {
            d.h = sh;
            d.w = static_cast<int>( static_cast<int64_t>( sh ) * gw / gh );
        }
        d.x = ( sw - d.w ) / 2;
        d.y = ( sh - d.h ) / 2;
        return d;
    }

    void reference( const std::vector<uint8_t> & image, int gw, int gh, const PresentRect & d, int sw, int sh, const uint32_t * pal, uint32_t black,
                    std::vector<uint32_t> & out )
    {
        out.assign( static_cast<size_t>( sw ) * sh, black );
        for ( int y = 0; y < d.h; ++y ) {
            const int sy = static_cast<int>( static_cast<int64_t>( y ) * gh / d.h );
            for ( int x = 0; x < d.w; ++x ) {
                const int sx = static_cast<int>( static_cast<int64_t>( x ) * gw / d.w );
                out[static_cast<size_t>( d.y + y ) * sw + d.x + x] = pal[image[static_cast<size_t>( sy ) * gw + sx]];
            }
        }
    }

    void cyclePalette( const uint32_t * base, uint32_t * pal, int step )
    {
        // fheroes2's cycling sets: 214-217, 218-221, 231-235, 238-241.
        std::copy( base, base + 256, pal );
        const int sets[4][2] = { { 214, 4 }, { 218, 4 }, { 231, 5 }, { 238, 4 } };
        for ( const auto & s : sets ) {
            for ( int i = 0; i < s[1]; ++i ) {
                pal[s[0] + i] = base[s[0] + ( i + step ) % s[1]];
            }
        }
    }

    void runCase( const Case & c, int steps, PresentStats & total )
    {
        const int pitch = c.sw + 3; // pixels; a pitch wider than the surface
        std::vector<uint32_t> surface( static_cast<size_t>( pitch ) * c.sh, 0xdeadbeef );
        std::vector<uint32_t> screen( static_cast<size_t>( c.sw ) * c.sh, 0xdeadbeef );
        std::vector<uint32_t> ref;
        std::vector<uint8_t> image( static_cast<size_t>( c.gw ) * c.gh );
        for ( auto & v : image ) {
            v = static_cast<uint8_t>( rnd( 256 ) );
        }

        uint32_t base[256];
        uint32_t pal[256];
        for ( int i = 0; i < 256; ++i ) {
            base[i] = rng() | 1u;
        }
        std::copy( base, base + 256, pal );
        const uint32_t black = 0xff000000u;

        PresentRect dest = c.keepAspect ? fit( c.gw, c.gh, c.sw, c.sh ) : PresentRect{ 0, 0, c.sw, c.sh };
        Presenter p;
        p.setGeometry( c.gw, c.gh, dest, c.sw, c.sh );
        p.setPalette( pal );

        std::vector<PresentRect> rects;
        int cycle = 0;
        for ( int step = 0; step < steps; ++step ) {
            int rx = 0, ry = 0, rw = 0, rh = 0;
            const int kind = rnd( 20 );
            if ( kind < 10 ) {
                // Change a few pixels inside a reported area (often much bigger than the change).
                rx = rnd( c.gw );
                ry = rnd( c.gh );
                rw = 1 + rnd( c.gw - rx );
                rh = 1 + rnd( c.gh - ry );
                const int n = rnd( 40 );
                for ( int i = 0; i < n; ++i ) {
                    const int x = rx + rnd( rw );
                    const int y = ry + rnd( rh );
                    image[static_cast<size_t>( y ) * c.gw + x] = static_cast<uint8_t>( rnd( 3 ) == 0 ? 214 + rnd( 28 ) : rnd( 256 ) );
                }
                if ( rnd( 3 ) == 0 ) {
                    // A block filled with one value, as a blit does.
                    const uint8_t v = static_cast<uint8_t>( rnd( 256 ) );
                    const int bw = 1 + rnd( rw ), bh = 1 + rnd( rh );
                    for ( int y = ry; y < ry + bh; ++y ) {
                        for ( int x = rx; x < rx + bw; ++x ) {
                            image[static_cast<size_t>( y ) * c.gw + x] = v;
                        }
                    }
                }
            }
            else if ( kind < 14 ) {
                cyclePalette( base, pal, ++cycle );
                p.setPalette( pal );
                if ( rnd( 2 ) == 0 ) {
                    rx = rnd( c.gw );
                    ry = rnd( c.gh );
                    rw = 1 + rnd( c.gw - rx );
                    rh = 1 + rnd( c.gh - ry );
                    image[static_cast<size_t>( ry ) * c.gw + rx] ^= 0x55;
                }
            }
            else if ( kind < 15 ) {
                // Another palette altogether.
                for ( int i = 0; i < 256; ++i ) {
                    base[i] = rng() | 1u;
                }
                std::copy( base, base + 256, pal );
                p.setPalette( pal );
            }
            else if ( kind < 16 ) {
                // A few colours change.
                for ( int i = rnd( 5 ); i >= 0; --i ) {
                    base[rnd( 256 )] = rng() | 1u;
                }
                std::copy( base, base + 256, pal );
                p.setPalette( pal );
            }
            else if ( kind < 17 ) {
                p.invalidate();
            }
            else if ( kind < 18 ) {
                // The same palette again: nothing to do.
                p.setPalette( pal );
            }
            else {
                // Nothing changed, but the game reports an area anyway.
                rx = 0;
                ry = 0;
                rw = c.gw;
                rh = c.gh;
            }

            if ( step == steps / 3 ) {
                // Another program drew over the screen (full screen): everything again.
                for ( int y = 0; y < c.sh; y += 3 ) {
                    std::fill_n( surface.begin() + static_cast<ptrdiff_t>( y ) * pitch, c.sw, 0x0badf00du );
                }
                std::fill( screen.begin(), screen.end(), 0x0badf00du );
                p.invalidate( true );
            }

            if ( step == steps / 2 ) {
                // A new surface (the window was resized and back): it starts with junk.
                std::fill( surface.begin(), surface.end(), 0x12345678u );
                for ( int y = 0; y < c.sh; ++y ) {
                    std::fill_n( surface.begin() + static_cast<ptrdiff_t>( y ) * pitch + c.sw, pitch - c.sw, 0xdeadbeefu );
                }
                p.setGeometry( c.gw, c.gh, dest, c.sw, c.sh );
            }

            rects.clear();
            p.present( image.data(), rx, ry, rw, rh, surface.data(), pitch * 4, black, rects, total );

            for ( const PresentRect & r : rects ) {
                if ( r.x < 0 || r.y < 0 || r.w <= 0 || r.h <= 0 || r.x + r.w > c.sw || r.y + r.h > c.sh ) {
                    fail( "rectangle outside the surface", step, r.x, r.y );
                    continue;
                }
                for ( int y = r.y; y < r.y + r.h; ++y ) {
                    for ( int x = r.x; x < r.x + r.w; ++x ) {
                        screen[static_cast<size_t>( y ) * c.sw + x] = surface[static_cast<size_t>( y ) * pitch + x];
                    }
                }
            }
            if ( rects.size() > Presenter::maxRects ) {
                fail( "too many rectangles", step, static_cast<int>( rects.size() ), 0 );
            }

            reference( image, c.gw, c.gh, dest, c.sw, c.sh, pal, black, ref );
            for ( int y = 0; y < c.sh; ++y ) {
                for ( int x = 0; x < c.sw; ++x ) {
                    const uint32_t want = ref[static_cast<size_t>( y ) * c.sw + x];
                    if ( surface[static_cast<size_t>( y ) * pitch + x] != want ) {
                        fail( "surface differs", step, x, y );
                        y = c.sh;
                        break;
                    }
                    if ( screen[static_cast<size_t>( y ) * c.sw + x] != want ) {
                        fail( "plotted screen differs", step, x, y );
                        y = c.sh;
                        break;
                    }
                }
            }
            // Pixels beyond the surface width (pitch padding) must never be written.
            for ( int y = 0; y < c.sh; ++y ) {
                for ( int x = c.sw; x < pitch; ++x ) {
                    if ( surface[static_cast<size_t>( y ) * pitch + x] != 0xdeadbeef ) {
                        fail( "wrote past the surface width", step, x, y );
                    }
                }
            }
        }
    }

    // The costs the presenter is for: palette cycling on a screen where only part uses
    // the cycling colours, and a big reported area with one small change.
    int checkSavings()
    {
        const int gw = 640, gh = 480;
        std::vector<uint8_t> image( static_cast<size_t>( gw ) * gh, 10 );
        for ( int y = 300; y < 340; ++y ) {
            for ( int x = 100; x < 200; ++x ) {
                image[static_cast<size_t>( y ) * gw + x] = 215; // water
            }
        }
        std::vector<uint32_t> surface( static_cast<size_t>( gw ) * gh );
        uint32_t base[256], pal[256];
        for ( int i = 0; i < 256; ++i ) {
            base[i] = static_cast<uint32_t>( i * 0x010101 );
        }
        Presenter p;
        p.setGeometry( gw, gh, { 0, 0, gw, gh }, gw, gh );
        p.setPalette( base );
        std::vector<PresentRect> rects;
        PresentStats s;
        p.present( image.data(), 0, 0, gw, gh, surface.data(), gw * 4, 0, rects, s );

        int bad = 0;
        PresentStats c;
        cyclePalette( base, pal, 1 );
        p.setPalette( pal );
        p.present( image.data(), 0, 0, 0, 0, surface.data(), gw * 4, 0, rects, c );
        std::printf( "cycling: %llu pixels converted, %llu plotted in %zu rectangles (whole screen %d)\n", static_cast<unsigned long long>( c.pixelsConverted ),
                     static_cast<unsigned long long>( c.pixelsPlotted ), rects.size(), gw * gh );
        if ( c.pixelsConverted != 100 * 40 || c.pixelsPlotted > 3 * 64 * 4 * 16 ) {
            std::printf( "FAIL cycling should touch only the water\n" );
            ++bad;
        }

        PresentStats d;
        image[static_cast<size_t>( 50 ) * gw + 600] = 1;
        p.present( image.data(), 0, 0, gw, gh, surface.data(), gw * 4, 0, rects, d );
        std::printf( "one pixel in a full-screen area: %llu converted, %llu plotted\n", static_cast<unsigned long long>( d.pixelsConverted ),
                     static_cast<unsigned long long>( d.pixelsPlotted ) );
        if ( d.pixelsConverted != 1 || d.pixelsPlotted != 64 * 16 || rects.size() != 1 ) {
            std::printf( "FAIL one changed pixel should plot one cell\n" );
            ++bad;
        }

        PresentStats e;
        p.present( image.data(), 0, 0, gw, gh, surface.data(), gw * 4, 0, rects, e );
        if ( e.pixelsConverted != 0 || !rects.empty() ) {
            std::printf( "FAIL nothing changed but something was drawn\n" );
            ++bad;
        }
        return bad;
    }
}

int main()
{
    const Case cases[] = {
        { 640, 480, 640, 480, true }, // window, 1:1
        { 640, 480, 1280, 960, true }, // x2
        { 640, 480, 1920, 1080, true }, // full screen: scaled 2.25, borders
        { 1024, 768, 1280, 1024, true }, // letterbox, not scaled vertically
        { 1024, 768, 1024, 768, true },
        { 643, 481, 643, 481, true }, // odd width: rows not word aligned
        { 643, 481, 1000, 1000, true },
        { 200, 150, 333, 250, false }, // stretched, not keeping aspect
        { 130, 70, 130, 70, true }, // smaller than one band/cell grid
    };

    PresentStats total;
    for ( const Case & c : cases ) {
        runCase( c, 300, total );
    }
    failures += checkSavings();

    std::printf( "frames %llu, full %llu, palette %llu, converted %llu, plotted %llu, rects %llu\n", static_cast<unsigned long long>( total.frames ),
                 static_cast<unsigned long long>( total.fullFrames ), static_cast<unsigned long long>( total.paletteFrames ),
                 static_cast<unsigned long long>( total.pixelsConverted ), static_cast<unsigned long long>( total.pixelsPlotted ),
                 static_cast<unsigned long long>( total.rects ) );
    if ( failures > 0 ) {
        std::printf( "%d failures\n", failures );
        return 1;
    }
    std::printf( "all OK\n" );
    return 0;
}
