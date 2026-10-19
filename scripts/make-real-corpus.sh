#!/bin/bash
# Prepares the REAL-WORLD tool corpus (test-corpus/real, see SOURCES.md) on macOS CI.
# Real files are copied as-is. Some tools need formats the real files don't come in, so we derive them while
# keeping the real content (the derivation is listed in DERIVED.txt next to the files):
#   jellyfish.jpg (real camera EXIF+GPS) → .png/.heic/.tiff via morph-cli (ImageIO keeps the EXIF/GPS); .webp gets
#     the photo's real EXIF block copied into a RIFF EXIF chunk (ImageIO can't write WebP)
#   armstrong.wav (real speech) → .flac/.m4a with title/artist tags (so there is metadata to remove)
#   nasa-ksc.webm (real video+speech) → .mp4/.mov/.mkv (H.264 + AAC, 2 s keyframes) with title/comment tags
#   lame-3.100.tar.gz → .tar (gunzip of the real archive)
#   traversal.zip: hostile archive with a "../" entry (Extract must not write outside its folder)
# usage: make-real-corpus.sh <out-dir> <morph-cli>
set -euo pipefail
OUT=$1; CLI=$2
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FF="$MORPH_TOOLS_DIR/ffmpeg"
rm -rf "$OUT"; mkdir -p "$OUT"
cp "$ROOT"/test-corpus/real/*.{jpg,wav,mp3,webm,pdf,zip,gz} "$OUT/"
( cd "$OUT" && shasum -a 256 -c <(grep -o '`[^`]*` |.*`[0-9a-f]\{64\}`' "$ROOT/test-corpus/real/SOURCES.md" \
    | sed -E 's/^`([^`]*)`.*`([0-9a-f]{64})`$/\2  \1/') )
D="$OUT/DERIVED.txt"; : > "$D"
note() { echo "$1" >> "$D"; }
q() { "$FF" -hide_banner -loglevel error -nostdin -y "$@"; }

J="$OUT/jellyfish-panasonic-gps.jpg"
for f in png heic tiff; do
  out=$("$CLI" convert "$J" "$f") && note "$(basename "$out"): morph-cli convert from the real JPEG (EXIF/GPS carried by ImageIO)"
done
"$CLI" convert "$J" webp >/dev/null
python3 - "$J" "$OUT/jellyfish-panasonic-gps.webp" <<'PY'
import struct, sys
jpg, webp = open(sys.argv[1], "rb").read(), sys.argv[2]
i, exif = 2, None
while i + 4 <= len(jpg) and jpg[i] == 0xFF:
    m, n = jpg[i + 1], struct.unpack(">H", jpg[i + 2:i + 4])[0]
    if m == 0xE1 and jpg[i + 4:i + 10] == b"Exif\0\0": exif = jpg[i + 10:i + 2 + n]; break
    if m == 0xDA: break
    i += 2 + n
assert exif, "no EXIF in source JPEG"
d = open(webp, "rb").read(); chunks, i = [], 12
while i + 8 <= len(d):
    n = struct.unpack("<I", d[i + 4:i + 8])[0]; chunks.append([d[i:i + 4], bytearray(d[i + 8:i + 8 + n])]); i += 8 + n + (n & 1)
if not any(c[0] == b"VP8X" for c in chunks):
    vp8 = next(c[1] for c in chunks if c[0] == b"VP8 ")
    w = struct.unpack("<H", vp8[6:8])[0] & 0x3FFF; h = struct.unpack("<H", vp8[8:10])[0] & 0x3FFF
    chunks.insert(0, [b"VP8X", bytearray([0, 0, 0, 0]) + (w - 1).to_bytes(3, "little") + (h - 1).to_bytes(3, "little")])
next(c for c in chunks if c[0] == b"VP8X")[1][0] |= 0x08
chunks.append([b"EXIF", bytearray(exif)])
body = b"WEBP" + b"".join(cc + struct.pack("<I", len(p)) + bytes(p) + (b"\0" if len(p) & 1 else b"") for cc, p in chunks)
open(webp, "wb").write(b"RIFF" + struct.pack("<I", len(body)) + body)
PY
note "jellyfish-panasonic-gps.webp: morph-cli convert, then the real JPEG's EXIF (incl. GPS) copied into a RIFF EXIF chunk"

W="$OUT/armstrong-small-step.wav"
TAGS=(-metadata "title=One small step (test tag)" -metadata "artist=NASA (test tag)")
q -i "$W" "${TAGS[@]}" -c:a flac "$OUT/armstrong-small-step.flac"
q -i "$W" "${TAGS[@]}" -c:a aac -b:a 64k "$OUT/armstrong-small-step.m4a"
note "armstrong-small-step.flac/.m4a: transcoded from the real WAV + title/artist tags"

V="$OUT/nasa-ksc-swearing-in.webm"
VT=(-metadata "title=KSC swearing-in (test tag)" -metadata "comment=Morph test tag")
for f in mp4 mov mkv; do
  q -t 40 -i "$V" "${VT[@]}" -c:v h264_videotoolbox -allow_sw 1 -b:v 1200k -g 60 -pix_fmt yuv420p -c:a aac -b:a 128k "$OUT/nasa-ksc-swearing-in.$f"
done
note "nasa-ksc-swearing-in.mp4/.mov/.mkv: first 40 s of the real WebM transcoded (H.264 + AAC, keyframe every 60 frames) + title/comment tags"

python3 - "$OUT" <<'PY'
import gzip, shutil, sys, zipfile, os
out = sys.argv[1]
with gzip.open(os.path.join(out, "lame-3.100.tar.gz")) as s, open(os.path.join(out, "lame-3.100.tar"), "wb") as d: shutil.copyfileobj(s, d)
with zipfile.ZipFile(os.path.join(out, "traversal.zip"), "w") as z:
    z.writestr("ok.txt", "harmless\n")
    z.writestr("../ESCAPED-by-morph-test.txt", "if you can read this outside the extract folder, extraction is unsafe\n")
PY
note "lame-3.100.tar: gunzip of the real lame-3.100.tar.gz"
note "traversal.zip: hostile archive with ok.txt and ../ESCAPED-by-morph-test.txt"
cat "$D"; ls -la "$OUT"
