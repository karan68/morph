#!/bin/bash
# Builds Morph's bundled third-party tools for Apple silicon, macOS 13+ (spec §7.2):
#   LGPL FFmpeg (ffmpeg + ffprobe, shared libs, --disable-network, VideoToolbox/AudioToolbox)
#   + LAME (LGPL), libogg/libvorbis/libopus/libvpx/libwebp (BSD-style), and libarchive's bsdtar (BSD).
# Output: $OUT/Helpers/{ffmpeg,ffprobe,bsdtar}, $OUT/Frameworks/*.dylib (install names @rpath/…),
#         $OUT/sources/*.tar.* (exact sources, for LGPL compliance), $OUT/CONFIGURE.txt.
# Runs on CI (macos runner). Not runnable where executing fresh binaries is blocked.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/deps-versions.env"
OUT="${1:-$ROOT/vendor-out}"
WORK="${WORK:-$ROOT/.build/deps}"
PREFIX="$WORK/prefix"
export MACOSX_DEPLOYMENT_TARGET=13.0
export CFLAGS="-arch arm64 -mmacosx-version-min=13.0 -O2"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-arch arm64 -mmacosx-version-min=13.0"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"   # never pick up Homebrew .pc files
JOBS="$(sysctl -n hw.ncpu)"
mkdir -p "$WORK/src" "$PREFIX" "$OUT/sources"
rm -rf "$OUT/Helpers" "$OUT/Frameworks"; mkdir -p "$OUT/Helpers" "$OUT/Frameworks"

fetch() { # NAME URL SHA
  local name=$1 url=$2 sha=$3 f="$WORK/src/$(basename "$2")"
  [ -f "$f" ] || curl -fsSL --retry 3 -o "$f" "$url"
  echo "$sha  $f" | shasum -a 256 -c - >/dev/null || { echo "SHA-256 mismatch for $name" >&2; exit 1; }
  cp "$f" "$OUT/sources/"
  local dir="$WORK/src/$name"; rm -rf "$dir"; mkdir -p "$dir"
  tar -xf "$f" -C "$dir" --strip-components 1
  echo "$dir"
}

echo "== lame";   d=$(fetch lame "$LAME_URL" "$LAME_SHA256"); cd "$d"
# lame_init_old is an internal, deprecated entry point; dropping it from the export list avoids a known
# macOS link failure (same fix Homebrew applies). Public API used by FFmpeg is unaffected.
sed -i '' '/^lame_init_old$/d' include/libmp3lame.sym
./configure --prefix="$PREFIX" --enable-shared --disable-static --disable-frontend --disable-dependency-tracking --disable-debug >/dev/null
make -j"$JOBS" >/dev/null && make install >/dev/null

echo "== ogg";    d=$(fetch ogg "$OGG_URL" "$OGG_SHA256"); cd "$d"
./configure --prefix="$PREFIX" --enable-shared --disable-static >/dev/null && make -j"$JOBS" >/dev/null && make install >/dev/null

echo "== vorbis"; d=$(fetch vorbis "$VORBIS_URL" "$VORBIS_SHA256"); cd "$d"
sed -i '' 's/ -force_cpusubtype_ALL//g' configure   # flag rejected by current clang on arm64
./configure --prefix="$PREFIX" --with-ogg="$PREFIX" --enable-shared --disable-static --disable-docs --disable-examples >/dev/null
make -j"$JOBS" >/dev/null && make install >/dev/null

echo "== opus";   d=$(fetch opus "$OPUS_URL" "$OPUS_SHA256"); cd "$d"
./configure --prefix="$PREFIX" --enable-shared --disable-static --disable-doc --disable-extra-programs >/dev/null
make -j"$JOBS" >/dev/null && make install >/dev/null

echo "== vpx";    d=$(fetch vpx "$VPX_URL" "$VPX_SHA256"); cd "$d"
./configure --prefix="$PREFIX" --target=arm64-darwin22-gcc --enable-shared --disable-static \
  --disable-examples --disable-tools --disable-docs --disable-unit-tests --enable-pic \
  --extra-cflags="-mmacosx-version-min=13.0" >/dev/null
make -j"$JOBS" >/dev/null && make install >/dev/null

echo "== webp";   d=$(fetch webp "$WEBP_URL" "$WEBP_SHA256"); cd "$d"
./configure --prefix="$PREFIX" --enable-shared --disable-static --enable-libwebpmux --enable-libwebpdemux \
  --disable-gl --disable-sdl --disable-png --disable-jpeg --disable-tiff --disable-gif --disable-wic >/dev/null
make -j"$JOBS" >/dev/null && make install >/dev/null

echo "== ffmpeg"; d=$(fetch ffmpeg "$FFMPEG_URL" "$FFMPEG_SHA256"); cd "$d"
FFMPEG_FLAGS="--prefix=$PREFIX --arch=arm64 --target-os=darwin --cc=clang --enable-shared --disable-static \
 $FFMPEG_COMMON_FLAGS --enable-videotoolbox --enable-audiotoolbox \
 --extra-cflags=-I$PREFIX/include --extra-ldflags=-L$PREFIX/lib"
# shellcheck disable=SC2086
./configure $FFMPEG_FLAGS >/dev/null
make -j"$JOBS" >/dev/null && make install >/dev/null
{ echo "FFmpeg $(basename "$FFMPEG_URL") configured with:"; echo "./configure $FFMPEG_FLAGS" | sed "s#$PREFIX#<prefix>#g"
  echo; echo "No changes were made to the FFmpeg source code."; } > "$OUT/CONFIGURE.txt"

echo "== libarchive (bsdtar)"; d=$(fetch libarchive "$ARCHIVE_URL" "$ARCHIVE_SHA256"); mkdir -p "$d/b"; cd "$d/b"
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
  -DCMAKE_IGNORE_PREFIX_PATH=/opt/homebrew -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF \
  -DENABLE_TAR=ON -DENABLE_TAR_SHARED=OFF -DENABLE_CPIO=OFF -DENABLE_CAT=OFF -DENABLE_UNZIP=OFF -DENABLE_TEST=OFF \
  -DENABLE_OPENSSL=OFF -DENABLE_MBEDTLS=OFF -DENABLE_NETTLE=OFF -DENABLE_LIBXML2=OFF -DENABLE_EXPAT=OFF \
  -DENABLE_LZMA=OFF -DENABLE_ZSTD=OFF -DENABLE_LZ4=OFF -DENABLE_LZO=OFF -DENABLE_LIBB2=OFF -DENABLE_CNG=OFF \
  -DENABLE_ZLIB=ON -DENABLE_BZip2=ON -DENABLE_ICONV=ON >/dev/null
make -j"$JOBS" bsdtar >/dev/null
cp bin/bsdtar "$OUT/Helpers/bsdtar"

echo "== relocate to @rpath"
cp "$PREFIX/bin/ffmpeg" "$PREFIX/bin/ffprobe" "$OUT/Helpers/"
# Copy each real dylib under its install-name basename (e.g. libavcodec.61.dylib).
for lib in "$PREFIX"/lib/*.dylib; do
  [ -L "$lib" ] && continue
  id=$(otool -D "$lib" | tail -1)
  cp "$lib" "$OUT/Frameworks/$(basename "$id")"
done
fix() { # rewrite every non-system dependency to @rpath/<basename>; it must be one of the bundled dylibs
  local f=$1 dep base
  for dep in $(otool -L "$f" | awk 'NR>1{print $1}'); do
    case "$dep" in /usr/lib/*|/System/*|@rpath/*) continue ;; esac
    base=$(basename "$dep")
    [ "$base" = "$(basename "$f")" ] && continue
    [ -f "$OUT/Frameworks/$base" ] || { echo "ERROR: $f depends on unbundled $dep" >&2; exit 1; }
    install_name_tool -change "$dep" "@rpath/$base" "$f"
  done
}
for f in "$OUT"/Frameworks/*.dylib; do install_name_tool -id "@rpath/$(basename "$f")" "$f"; fix "$f"; done
for f in "$OUT"/Helpers/ffmpeg "$OUT"/Helpers/ffprobe; do
  fix "$f"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$f" 2>/dev/null || true
done
# install_name_tool invalidates signatures; arm64 requires a valid (ad-hoc) one to run.
codesign --force --sign - "$OUT"/Frameworks/*.dylib "$OUT"/Helpers/*

echo "== verify"
if otool -L "$OUT"/Helpers/* "$OUT"/Frameworks/*.dylib | grep -E "/opt/homebrew|/usr/local|$PREFIX"; then
  echo "ERROR: non-bundled dependency found" >&2; exit 1
fi
for f in "$OUT"/Helpers/* "$OUT"/Frameworks/*.dylib; do
  minos=$(otool -l "$f" | awk '/LC_BUILD_VERSION/{f=1} f&&/minos/{print $2; exit}')
  [ "$minos" = "13.0" ] || { echo "ERROR: $f minos=$minos (expected 13.0)" >&2; exit 1; }
done
"$OUT/Helpers/ffmpeg" -hide_banner -version | head -1
"$OUT/Helpers/ffmpeg" -hide_banner -L | grep -i -m1 "GNU Lesser General Public License" || { echo "ERROR: FFmpeg is not LGPL" >&2; exit 1; }
"$OUT/Helpers/ffmpeg" -hide_banner -encoders 2>/dev/null | grep -E "libmp3lame|libopus|libvorbis|libvpx-vp9|libwebp |h264_videotoolbox|wmav2|wmv2|mpeg4 " 
"$OUT/Helpers/bsdtar" --version
ls -la "$OUT/Helpers" "$OUT/Frameworks"
echo "deps OK"
