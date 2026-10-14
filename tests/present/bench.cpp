// Replays frames recorded from a play session through the old present path (riscos1-3:
// everything converted and plotted when the palette cycles, the whole reported area
// otherwise) and through riscos_present.h, for several surface sizes. The two surfaces
// must stay identical. Prints the work each does: surface pixels written, pixels
// plotted, rectangles, time.
//
//   g++ -std=c++17 -O2 -I<tree>/src/engine tests/present/bench.cpp -lz -o bench
//   ./bench trace.gz [frames]
//
// The trace is gzip: per frame, 7 int32 (0x46483254, game width, height, the reported
// area x, y, w, h), the 256 uint32 palette, then the game screen (width x height
// bytes). It comes from a host build (BUILDING.md) whose _riscosRender writes it.

#include "riscos_present.h"

#include <chrono>
#include <cstdio>
#include <cstring>
#include <vector>
#include <zlib.h>

using namespace fheroes2::riscos;

namespace
{
    struct Frame
    {
        int32_t gw, gh, rx, ry, rw, rh;
        uint32_t palette[256];
        std::vector<uint8_t> image;
    };

    struct Geometry
    {
        const char * name;
        int sw, sh;
    };

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

    // The riscos1-3 present path (patch 0003), work counted the same way.
    struct OldPath
    {
        int gw = 0, gh = 0, sw = 0, sh = 0;
        PresentRect dest{};
        std::vector<int32_t> xMap, yMap;
        uint32_t palette[256]{};
        bool havePalette = false;
        uint64_t written = 0, plotted = 0, rects = 0;

        void setup( int w, int h, int s_w, int s_h )
        {
            gw = w;
            gh = h;
            sw = s_w;
            sh = s_h;
            dest = fit( gw, gh, sw, sh );
            xMap.resize( dest.w );
            for ( int x = 0; x < dest.w; ++x )
                xMap[x] = static_cast<int32_t>( static_cast<int64_t>( x ) * gw / dest.w );
            yMap.resize( dest.h );
            for ( int y = 0; y < dest.h; ++y )
                yMap[y] = static_cast<int32_t>( static_cast<int64_t>( y ) * gh / dest.h );
            havePalette = false;
        }

        static int32_t up( int32_t src, int32_t d, int32_t g )
        {
            return static_cast<int32_t>( ( static_cast<int64_t>( src ) * d + g - 1 ) / g );
        }

        void present( const Frame & f, uint32_t * pixels, int pitch )
        {
            bool full = !havePalette || std::memcmp( palette, f.palette, sizeof( palette ) ) != 0;
            std::memcpy( palette, f.palette, sizeof( palette ) );
            havePalette = true;

            int ax = full ? 0 : f.rx, ay = full ? 0 : f.ry, aw = full ? gw : f.rw, ah = full ? gh : f.rh;
            ax = std::clamp( ax, 0, gw );
            ay = std::clamp( ay, 0, gh );
            aw = std::clamp( aw, 0, gw - ax );
            ah = std::clamp( ah, 0, gh - ay );
            const int dx0 = up( ax, dest.w, gw ), dx1 = up( ax + aw, dest.w, gw );
            const int dy0 = up( ay, dest.h, gh ), dy1 = up( ay + ah, dest.h, gh );

            if ( full ) {
                for ( int y = 0; y < sh; ++y )
                    std::fill_n( pixels + static_cast<ptrdiff_t>( y ) * pitch, sw, 0u );
                written += static_cast<uint64_t>( sw ) * sh;
            }
            int prevY = -1;
            const uint32_t * prevRow = nullptr;
            for ( int dy = dy0; dy < dy1; ++dy ) {
                uint32_t * out = pixels + static_cast<ptrdiff_t>( dest.y + dy ) * pitch + dest.x + dx0;
                const int sy = yMap[dy];
                if ( sy == prevY && prevRow ) {
                    std::memcpy( out, prevRow, static_cast<size_t>( dx1 - dx0 ) * 4 );
                }
                else {
                    const uint8_t * in = f.image.data() + static_cast<ptrdiff_t>( sy ) * gw;
                    for ( int dx = dx0; dx < dx1; ++dx )
                        out[dx - dx0] = palette[in[xMap[dx]]];
                    prevY = sy;
                    prevRow = out;
                }
            }
            written += static_cast<uint64_t>( dx1 - dx0 ) * ( dy1 - dy0 );
            const uint64_t area = full ? static_cast<uint64_t>( sw ) * sh : static_cast<uint64_t>( dx1 - dx0 ) * ( dy1 - dy0 );
            if ( area ) {
                plotted += area;
                rects += 1;
            }
        }
    };

    bool readFrame( gzFile in, Frame & f )
    {
        int32_t h[7];
        if ( gzread( in, h, sizeof( h ) ) != static_cast<int>( sizeof( h ) ) || h[0] != 0x46483254 )
            return false;
        f.gw = h[1];
        f.gh = h[2];
        f.rx = h[3];
        f.ry = h[4];
        f.rw = h[5];
        f.rh = h[6];
        if ( gzread( in, f.palette, 1024 ) != 1024 )
            return false;
        f.image.resize( static_cast<size_t>( f.gw ) * f.gh );
        return gzread( in, f.image.data(), static_cast<unsigned>( f.image.size() ) ) == static_cast<int>( f.image.size() );
    }
}

int main( int argc, char ** argv )
{
    if ( argc < 2 ) {
        std::fprintf( stderr, "usage: bench trace.gz [max frames]\n" );
        return 2;
    }
    const long maxFrames = argc > 2 ? std::atol( argv[2] ) : 100000;

    std::vector<Frame> frames;
    gzFile in = gzopen( argv[1], "rb" );
    Frame f;
    while ( static_cast<long>( frames.size() ) < maxFrames && readFrame( in, f ) )
        frames.push_back( f );
    gzclose( in );
    if ( frames.empty() )
        return 1;
    const int gw = frames[0].gw, gh = frames[0].gh;
    int paletteChanges = 0;
    for ( size_t i = 1; i < frames.size(); ++i )
        paletteChanges += std::memcmp( frames[i].palette, frames[i - 1].palette, 1024 ) != 0;
    std::printf( "%zu frames of %dx%d, %d palette changes\n", frames.size(), gw, gh, paletteChanges );

    const Geometry geometries[] = { { "window 1:1", gw, gh }, { "window x2", gw * 2, gh * 2 }, { "full screen 1920x1080", 1920, 1080 } };
    int bad = 0;
    for ( const Geometry & g : geometries ) {
        const int pitch = g.sw;
        std::vector<uint32_t> a( static_cast<size_t>( pitch ) * g.sh ), b( a.size() );
        OldPath old;
        old.setup( gw, gh, g.sw, g.sh );
        Presenter p;
        p.setGeometry( gw, gh, fit( gw, gh, g.sw, g.sh ), g.sw, g.sh );
        PresentStats st;
        std::vector<PresentRect> rects;
        double tOld = 0, tNew = 0;
        size_t mismatch = 0;
        for ( const Frame & fr : frames ) {
            auto t0 = std::chrono::steady_clock::now();
            old.present( fr, a.data(), pitch );
            auto t1 = std::chrono::steady_clock::now();
            p.setPalette( fr.palette );
            p.present( fr.image.data(), fr.rx, fr.ry, fr.rw, fr.rh, b.data(), pitch * 4, 0u, rects, st );
            auto t2 = std::chrono::steady_clock::now();
            tOld += std::chrono::duration<double, std::milli>( t1 - t0 ).count();
            tNew += std::chrono::duration<double, std::milli>( t2 - t1 ).count();
            if ( a != b )
                ++mismatch;
        }
        const double n = static_cast<double>( frames.size() );
        std::printf( "%-22s old: %8.0f px written, %8.0f plotted, %.2f rects, %.3f ms per frame\n", g.name, old.written / n, old.plotted / n, old.rects / n, tOld / n );
        std::printf( "%-22s new: %8.0f px written, %8.0f plotted, %.2f rects, %.3f ms per frame; %zu frames differ\n", "", st.pixelsConverted / n,
                     st.pixelsPlotted / n, st.rects / n, tNew / n, mismatch );
        bad += mismatch != 0;
    }
    return bad ? 1 : 0;
}
