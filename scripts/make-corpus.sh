#!/bin/bash
# Builds the synthetic test corpus (spec §9/§12) on macOS CI: one sample per M1 input format.
# Uses the bundled LGPL ffmpeg/bsdtar ($MORPH_TOOLS_DIR), morph-cli for HEIC/AVIF (ImageIO),
# and the RAR fixture from libarchive's own BSD-licensed test suite (RAR can't be created with free tools).
# Usage: make-corpus.sh <out-dir> <morph-cli> <libarchive-source-tarball>
set -euo pipefail
C=$1; CLI=$2; LA_TAR=$3
FF="$MORPH_TOOLS_DIR/ffmpeg"; TAR="$MORPH_TOOLS_DIR/bsdtar"
rm -rf "$C"; mkdir -p "$C"
q() { "$FF" -hide_banner -loglevel error -nostdin -y "$@"; }
note() { echo "$1" >> "$C/CORPUS-NOTES.txt"; }

# Images (640x480 test pattern)
q -f lavfi -i "testsrc2=size=640x480:duration=1" -frames:v 1 "$C/sample.png"
q -i "$C/sample.png" -q:v 3 "$C/sample.jpg"
q -i "$C/sample.png" "$C/sample.bmp"
q -i "$C/sample.png" -c:v tiff "$C/sample.tiff"
q -i "$C/sample.png" -c:v libwebp -quality 85 "$C/sample.webp"
for f in heic avif; do
  if out=$("$CLI" convert "$C/sample.png" "$f" 2>/dev/null); then :; else note "sample.$f: this macOS can't write $f"; fi
done
# AVIF input fixture when this macOS can't encode AVIF: Kodak test image from libavif's test data
# ("released by the Eastman Kodak Company for unrestricted usage" per libavif tests/data/README.md), pinned.
if [ ! -f "$C/sample.avif" ]; then
  curl -fsSL --retry 3 -o "$C/sample.avif" https://raw.githubusercontent.com/AOMediaCodec/libavif/v1.1.1/tests/data/io/kodim03_yuv420_8bpc.avif
  echo "e69c973a3ddf635412c9a0c6cda66798102d0030303614873b337f658983ef5d  $C/sample.avif" | shasum -a 256 -c - >/dev/null
  note "sample.avif: pinned libavif test image (kodim03, 768x512) used as AVIF input"
fi
cat > "$C/sample.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="200" height="120" viewBox="0 0 200 120">
  <rect x="10" y="10" width="180" height="100" rx="18" fill="#5b47f5"/>
  <circle cx="100" cy="60" r="30" fill="#ffffff" fill-opacity="0.8"/>
</svg>
EOF
# Tagged copies for the Metadata tool (EXIF/GPS/TIFF/IPTC containing "MorphSecret").
mkdir -p "$C/tagged"
for f in jpg png tiff heic; do
  [ -f "$C/sample.$f" ] && "$CLI" tag-image "$C/sample.$f" "$C/tagged/tagged.$f" 2>/dev/null || note "tagged.$f: ImageIO couldn't write tags"
done
# ImageIO can't write WebP: add EXIF (ImageDescription) + XMP chunks containing "MorphSecret" at the RIFF level.
python3 - "$C/sample.webp" "$C/tagged/tagged.webp" <<'PY'
import struct, sys
d = open(sys.argv[1], "rb").read()
assert d[:4] == b"RIFF" and d[8:12] == b"WEBP"
chunks, i = [], 12
while i + 8 <= len(d):
    n = struct.unpack("<I", d[i + 4:i + 8])[0]
    chunks.append([d[i:i + 4], bytearray(d[i + 8:i + 8 + n])]); i += 8 + n + (n & 1)
if not any(c[0] == b"VP8X" for c in chunks):
    vp8 = next(c[1] for c in chunks if c[0] == b"VP8 ")
    w = struct.unpack("<H", vp8[6:8])[0] & 0x3FFF; h = struct.unpack("<H", vp8[8:10])[0] & 0x3FFF
    chunks.insert(0, [b"VP8X", bytearray([0, 0, 0, 0]) + (w - 1).to_bytes(3, "little") + (h - 1).to_bytes(3, "little")])
vp8x = next(c for c in chunks if c[0] == b"VP8X"); vp8x[1][0] |= 0x0C
desc = b"MorphSecret\0"
tiff = b"II*\0" + struct.pack("<I", 8) + struct.pack("<H", 1) + struct.pack("<HHII", 0x010E, 2, len(desc), 26) + struct.pack("<I", 0) + desc
chunks.append([b"EXIF", bytearray(tiff)])
chunks.append([b"XMP ", bytearray(b'<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"><rdf:Description xmlns:dc="http://purl.org/dc/elements/1.1/" dc:creator="MorphSecret"/></rdf:RDF></x:xmpmeta>')])
body = b"WEBP"
for cc, p in chunks:
    body += cc + struct.pack("<I", len(p)) + bytes(p) + (b"\0" if len(p) & 1 else b"")
open(sys.argv[2], "wb").write(b"RIFF" + struct.pack("<I", len(body)) + body)
PY

# Audio: 3 s stereo 44.1 kHz, title tag "MorphSecret"
A=(-f lavfi -i "sine=frequency=440:duration=3:sample_rate=44100" -ac 2 -metadata title=MorphSecret)
q "${A[@]}" -c:a libmp3lame -q:a 4 "$C/sample.mp3"
q "${A[@]}" -c:a aac -b:a 128k "$C/sample.m4a"
q "${A[@]}" -c:a pcm_s16le "$C/sample.wav"
q "${A[@]}" -c:a flac "$C/sample.flac"
q "${A[@]}" -c:a libvorbis -q:a 4 "$C/sample.ogg"
q "${A[@]}" -c:a libopus -b:a 96k "$C/sample.opus"
q "${A[@]}" -c:a pcm_s16be "$C/sample.aiff"
q "${A[@]}" -c:a wmav2 -b:a 128k "$C/sample.wma"

# Video: 3 s 320x240 30 fps + tone, title tag "MorphSecret"
V=(-f lavfi -i "testsrc2=size=320x240:rate=30:duration=3" -f lavfi -i "sine=frequency=330:duration=3" -shortest -metadata title=MorphSecret)
q "${V[@]}" -c:v h264_videotoolbox -allow_sw 1 -b:v 1M -pix_fmt yuv420p -c:a aac "$C/sample.mp4"
q "${V[@]}" -c:v h264_videotoolbox -allow_sw 1 -b:v 1M -pix_fmt yuv420p -c:a aac "$C/sample.mov"
q "${V[@]}" -c:v h264_videotoolbox -allow_sw 1 -b:v 1M -pix_fmt yuv420p -c:a aac "$C/sample.mkv"
q "${V[@]}" -c:v libvpx-vp9 -b:v 0 -crf 40 -deadline realtime -cpu-used 8 -c:a libopus "$C/sample.webm"
q "${V[@]}" -c:v mpeg4 -q:v 5 -c:a libmp3lame "$C/sample.avi"
q "${V[@]}" -c:v wmv2 -q:v 5 -c:a wmav2 "$C/sample.wmv"
q -f lavfi -i "testsrc2=size=240x180:rate=10:duration=2" -loop 0 "$C/sample.gif"

# Subtitles
printf '1\n00:00:00,500 --> 00:00:01,500\nHello <i>there</i>\n\n2\n00:00:02,000 --> 00:00:02,900\nSecond line\n' > "$C/sample.srt"
printf 'WEBVTT\n\n00:00.500 --> 00:01.500\nHello\n\n00:02.000 --> 00:02.900 align:start\nSecond\n' > "$C/sample.vtt"

# Archives
mkdir -p "$C/_payload/docs"; echo "alpha" > "$C/_payload/a.txt"; echo "beta" > "$C/_payload/docs/b.txt"
( cd "$C/_payload" && "$TAR" --format zip -cf ../sample.zip a.txt docs && "$TAR" --format pax -cf ../sample.tar a.txt docs \
  && "$TAR" --format pax -zcf ../sample.tar.gz a.txt docs )
rm -rf "$C/_payload"
tmp=$(mktemp -d); LA_DIR=$(basename "$LA_TAR" .tar.xz); tar -xf "$LA_TAR" -C "$tmp" --strip-components 3 "$LA_DIR/libarchive/test/test_read_format_rar.rar.uu"
python3 - "$tmp/test_read_format_rar.rar.uu" "$C/sample.rar" <<'EOF'
import binascii, sys
data = b""; started = False
for line in open(sys.argv[1]).read().splitlines():
    if line.startswith("begin "): started = True; continue
    if line == "end": break
    if started and line: data += binascii.a2b_uu(line)
open(sys.argv[2], "wb").write(data)
EOF
rm -rf "$tmp"

# PDF (for Compress / Metadata tools) via the app's own image → PDF path
"$CLI" convert "$C/sample.png" pdf >/dev/null
ls -la "$C"
