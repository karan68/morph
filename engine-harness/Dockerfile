# Morph engine harness (spec §9) — runs on the Tokyo VM (Ubuntu, x86_64).
# Builds the SAME pinned FFmpeg 7.1 + LAME/Ogg/Vorbis/Opus/VPX/WebP + libarchive sources as the macOS app
# (scripts/deps-versions.env, SHA-256 verified) with the same codec flags, minus macOS-only VideoToolbox/AudioToolbox.
# Ubuntu's own (GPL) ffmpeg is installed ONLY to generate test inputs — it is never shipped.
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential nasm yasm pkg-config cmake curl ca-certificates xz-utils python3 \
      zlib1g-dev libbz2-dev ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY scripts/deps-versions.env /tmp/deps-versions.env
ARG PREFIX=/opt/morph
ENV PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig LD_LIBRARY_PATH=$PREFIX/lib
RUN set -eux; . /tmp/deps-versions.env; mkdir -p /src && cd /src; \
    fetch() { curl -fsSL --retry 3 -o "$1.tar" "$2"; echo "$3  $1.tar" | sha256sum -c -; mkdir "$1"; tar -xf "$1.tar" -C "$1" --strip-components 1; }; \
    fetch lame "$LAME_URL" "$LAME_SHA256"; fetch ogg "$OGG_URL" "$OGG_SHA256"; fetch vorbis "$VORBIS_URL" "$VORBIS_SHA256"; \
    fetch opus "$OPUS_URL" "$OPUS_SHA256"; fetch vpx "$VPX_URL" "$VPX_SHA256"; fetch webp "$WEBP_URL" "$WEBP_SHA256"; \
    fetch ffmpeg "$FFMPEG_URL" "$FFMPEG_SHA256"; fetch libarchive "$ARCHIVE_URL" "$ARCHIVE_SHA256"; \
    J=$(nproc); \
    (cd lame && ./configure --prefix=$PREFIX --enable-shared --disable-static --disable-frontend >/dev/null && make -j$J >/dev/null && make install >/dev/null); \
    (cd ogg && ./configure --prefix=$PREFIX --enable-shared --disable-static >/dev/null && make -j$J >/dev/null && make install >/dev/null); \
    (cd vorbis && ./configure --prefix=$PREFIX --with-ogg=$PREFIX --enable-shared --disable-static --disable-docs --disable-examples >/dev/null && make -j$J >/dev/null && make install >/dev/null); \
    (cd opus && ./configure --prefix=$PREFIX --enable-shared --disable-static --disable-doc --disable-extra-programs >/dev/null && make -j$J >/dev/null && make install >/dev/null); \
    (cd vpx && ./configure --prefix=$PREFIX --enable-shared --disable-static --disable-examples --disable-tools --disable-docs --disable-unit-tests --enable-pic >/dev/null && make -j$J >/dev/null && make install >/dev/null); \
    (cd webp && ./configure --prefix=$PREFIX --enable-shared --disable-static --enable-libwebpmux --enable-libwebpdemux --disable-gl --disable-sdl --disable-png --disable-jpeg --disable-tiff --disable-gif >/dev/null && make -j$J >/dev/null && make install >/dev/null); \
    (cd ffmpeg && ./configure --prefix=$PREFIX --enable-shared --disable-static $FFMPEG_COMMON_FLAGS \
        --extra-cflags=-I$PREFIX/include --extra-ldflags=-L$PREFIX/lib >/dev/null && make -j$J >/dev/null && make install >/dev/null); \
    (mkdir libarchive/b && cd libarchive/b && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DENABLE_TAR=ON -DENABLE_TAR_SHARED=OFF \
        -DENABLE_CPIO=OFF -DENABLE_CAT=OFF -DENABLE_UNZIP=OFF -DENABLE_TEST=OFF -DENABLE_OPENSSL=OFF -DENABLE_LIBXML2=OFF -DENABLE_EXPAT=OFF \
        -DENABLE_LZMA=OFF -DENABLE_ZSTD=OFF -DENABLE_LZ4=OFF -DENABLE_LIBB2=OFF -DENABLE_ACL=OFF -DENABLE_XATTR=OFF >/dev/null && make -j$J bsdtar >/dev/null && cp bin/bsdtar $PREFIX/bin/); \
    mkdir -p /fixtures && cp libarchive/libarchive/test/test_read_format_rar.rar.uu /fixtures/; \
    $PREFIX/bin/ffmpeg -hide_banner -L | tr '\n' ' ' | grep -qi "Lesser General Public *License"; \
    $PREFIX/bin/ffmpeg -hide_banner -version | head -1; $PREFIX/bin/bsdtar --version; \
    rm -rf /src

ENV MORPH_FFMPEG=$PREFIX/bin/ffmpeg MORPH_FFPROBE=$PREFIX/bin/ffprobe MORPH_BSDTAR=$PREFIX/bin/bsdtar CORPUS_FFMPEG=/usr/bin/ffmpeg
WORKDIR /harness
