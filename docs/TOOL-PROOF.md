# Independent tool verification (real-world files)

Checked on Linux with tools that did **not** produce the results: exiftool, Ubuntu FFmpeg 6.1 (ffprobe, framemd5), Pillow, libheif, poppler, Python zipfile/tarfile, Ubuntu bsdtar. Inputs: [test-corpus/real](../test-corpus/real/SOURCES.md) (CC0 / public-domain photo, speech, MP3 with cover art, NASA video, USACE PDF, real software archives).

- **Tool results proven real: 62 / 62**
- **Fake results caught: 59 / 59** (input copied as the “result”, or a tampered extract folder)

## Compress — 24/24

| | Case | Checks | Fake caught |
|---|---|---|---|
| ✅ | compress-jpg-balanced | ✓ format jpg→jpg · ✓ smaller 2,411,520→399,507 B (−83%) · ✓ same size 2560x1920 · ✓ same picture luma PSNR 47.4 dB (≥30) · ✓ metadata kept (Keep on) GPS + DMC-TZ41 | ✅ |
| ✅ | compress-jpg-smallest | ✓ format jpg→jpg · ✓ smaller 2,411,520→121,792 B (−95%) · ✓ same size 2560x1920 · ✓ same picture luma PSNR 45.6 dB (≥27) · ✓ metadata kept (Keep on) GPS + DMC-TZ41 | ✅ |
| ✅ | compress-jpg-target-40pct | ✓ format jpg→jpg · ✓ smaller 2,411,520→790,809 B (−67%) · ✓ target size ≤ 964,608 B · ✓ same size 2560x1920 · ✓ same picture luma PSNR 48.1 dB (≥30) · ✓ metadata kept (Keep on) GPS + DMC-TZ41 | ✅ |
| ✅ | compress-jpg-percent-60 | ✓ format jpg→jpg · ✓ smaller 2,411,520→790,809 B (−67%) · ✓ percentage −60% → ≤ 964,608 B · ✓ same size 2560x1920 · ✓ same picture luma PSNR 48.1 dB (≥30) · ✓ metadata kept (Keep on) GPS + DMC-TZ41 | ✅ |
| ✅ | compress-jpg-maxdim-1080 | ✓ format jpg→jpg · ✓ smaller 2,411,520→87,600 B (−96%) · ✓ max dimension 2560x1920→1080x810 · ✓ same picture luma PSNR 48.8 dB (≥30) · ✓ metadata kept (Keep on) GPS + DMC-TZ41 | ✅ |
| ✅ | compress-jpg-no-meta | ✓ format jpg→jpg · ✓ smaller 2,411,520→395,893 B (−84%) · ✓ same size 2560x1920 · ✓ same picture luma PSNR 47.4 dB (≥30) · ✓ metadata removed (Keep off) 0 descriptive tags | ✅ |
| ✅ | compress-png-strong | ✓ format png→png · ✓ smaller 4,601,799→2,515,097 B (−45%) · ✓ same size 2560x1920 · ✓ same picture luma PSNR 45.3 dB (≥30) · ✓ metadata kept (Keep on) GPS + DMC-TZ41 | ✅ |
| ✅ | compress-heic-strong | ✓ format heic→heic · ✓ smaller 1,156,657→107,473 B (−91%) · ✓ same size 2560x1920 · ✓ same picture luma PSNR 47.1 dB (≥30) · ✓ metadata kept (Keep on) GPS + DMC-TZ41 | ✅ |
| ✅ | compress-webp-strong | ✓ format webp→webp · ✓ smaller 182,160→76,426 B (−58%) · ✓ same size 2560x1920 · ✓ same picture luma PSNR 48.2 dB (≥30) · ✓ metadata kept (Keep on) GPS + DMC-TZ41 | ✅ |
| ✅ | compress-tiff-strong | ✓ format tiff→tiff · ✓ smaller 14,751,724→3,871,780 B (−74%) · ✓ same size 2560x1920 · ✓ same picture luma PSNR 99.0 dB (≥30) · ✓ metadata kept (Keep on) GPS + DMC-TZ41 | ✅ |
| ✅ | compress-mp3-balanced | ✓ format mp3→mp3 · ✓ smaller 370,688→189,954 B (−49%) · ✓ same sound loudness-contour correlation 1.000 (≥0.95) · 13.48s (src 13.48s) | ✅ |
| ✅ | compress-mp3-target-50pct | ✓ format mp3→mp3 · ✓ smaller 370,688→189,954 B (−49%) · ✓ target size ≤ 185,344 B (+5%) · ✓ same sound loudness-contour correlation 1.000 (≥0.95) · 13.48s (src 13.48s) | ✅ |
| ✅ | compress-wav-balanced | ✓ format wav→flac · ✓ smaller 265,886→113,606 B (−57%) · ✓ lossless (sample-exact) 265,842 samples identical | ✅ |
| ✅ | compress-wav-smallest | ✓ format wav→flac · ✓ smaller 265,886→113,606 B (−57%) · ✓ lossless (sample-exact) 265,842 samples identical | ✅ |
| ✅ | compress-flac-balanced | ✓ format flac→flac · ✓ smaller 114,531→113,667 B (−1%) · ✓ lossless (sample-exact) 265,842 samples identical | ✅ |
| ✅ | compress-m4a-strong | ✓ format m4a→m4a · ✓ smaller 165,595→98,465 B (−41%) · ✓ same sound loudness-contour correlation 0.999 (≥0.95) · 24.15s (src 24.15s) | ✅ |
| ✅ | compress-mp4-balanced | ✓ format mp4→mp4 · ✓ smaller 5,916,700→2,580,134 B (−56%) · ✓ same frame size 320x212 · ✓ same picture luma PSNR 48.0 dB (≥30, offset +0) · ✓ same soundtrack loudness-contour correlation 1.000 (≥0.95) | ✅ |
| ✅ | compress-mov-balanced | ✓ format mov→mov · ✓ smaller 5,916,741→2,580,175 B (−56%) · ✓ same frame size 320x212 · ✓ same picture luma PSNR 48.0 dB (≥30, offset +0) · ✓ same soundtrack loudness-contour correlation 1.000 (≥0.95) | ✅ |
| ✅ | compress-mkv-balanced | ✓ format mkv→mkv · ✓ smaller 5,917,461→2,583,962 B (−56%) · ✓ same frame size 320x212 · ✓ same picture luma PSNR 48.0 dB (≥30, offset +0) · ✓ same soundtrack loudness-contour correlation 0.997 (≥0.95) | ✅ |
| ✅ | compress-mp4-percent-50 | ✓ format mp4→mp4 · ✓ smaller 5,916,700→2,283,792 B (−61%) · ✓ percentage −50% → ≤ 2,958,350 B · ✓ same frame size 320x212 · ✓ same picture luma PSNR 47.9 dB (≥30, offset +0) · ✓ same soundtrack loudness-contour correlation 1.000 (≥0.95) | ✅ |
| ✅ | compress-pdf-optimised-declines | ✓ declined, no bigger file written · FAIL: “nasa-plum-brook-factsheet-2008.pdf” is already well compressed — Morph couldn't make it smaller with these settings. The original is unchanged. | — |
| ✅ | compress-pdf-photo-balanced | ✓ format pdf→pdf · ✓ smaller 5,485,238→664,348 B (−88%) · ✓ same pages 1 pages · ✓ same text 0 chars · ✓ same pages visually min page PSNR 32.9 dB (≥25) | ✅ |
| ✅ | compress-pdf-photo-strong | ✓ format pdf→pdf · ✓ smaller 5,485,238→391,604 B (−93%) · ✓ same pages 1 pages · ✓ same text 0 chars · ✓ same pages visually min page PSNR 32.9 dB (≥25) | ✅ |
| ✅ | compress-png-balanced-keep-meta | ✓ format png→png · ✓ smaller 4,601,799→3,514,024 B (−24%) · ✓ same size 2560x1920 · ✓ same picture luma PSNR 99.0 dB (≥30) · ✓ metadata kept (Keep on) GPS + DMC-TZ41 | ✅ |

## Metadata (Remove All) — 13/13

| | Case | Checks | Fake caught |
|---|---|---|---|
| ✅ | metadata-jpg | ✓ input had metadata 87 tags e.g. IFD0:Make, IFD0:Model, IFD0:Software, ExifIFD:DateTimeOriginal · ✓ nothing from the original left · ✓ pixels identical lossless strip | ✅ |
| ✅ | metadata-png | ✓ input had metadata 86 tags e.g. IFD0:Make, IFD0:Model, IFD0:Software, ExifIFD:DateTimeOriginal · ✓ nothing from the original left · ✓ pixels identical lossless strip | ✅ |
| ✅ | metadata-heic | ✓ input had metadata 28 tags e.g. IFD0:Make, IFD0:Model, IFD0:Software, ExifIFD:DateTimeOriginal · ✓ nothing from the original left · ✓ same picture luma PSNR 57.2 dB (≥40) | ✅ |
| ✅ | metadata-webp | ✓ input had metadata 87 tags e.g. IFD0:Make, IFD0:Model, IFD0:Software, ExifIFD:DateTimeOriginal · ✓ nothing from the original left · ✓ pixels identical lossless strip | ✅ |
| ✅ | metadata-tiff | ✓ input had metadata 28 tags e.g. IFD0:Make, IFD0:Model, IFD0:Software, XMP-aux:SerialNumber · ✓ nothing from the original left · ✓ same picture luma PSNR 99.0 dB (≥40) | ✅ |
| ✅ | metadata-mp3-coverart | ✓ input had metadata 15 tags e.g. MPEG:Encoder, ID3v2_3:Artist, ID3v2_3:Album, ID3v2_3:Band · ✓ nothing from the original left · ✓ audio packets identical 518 packets · ✓ cover art removed 1→0 | ✅ |
| ✅ | metadata-flac | ✓ input had metadata 3 tags e.g. Vorbis:Title, Vorbis:Artist, Vorbis:Encoder · ✓ nothing from the original left · ✓ audio packets identical 231 packets | ✅ |
| ✅ | metadata-m4a | ✓ input had metadata 3 tags e.g. ItemList:Title, ItemList:Artist, ItemList:Encoder · ✓ nothing from the original left · ✓ audio packets identical 261 packets | ✅ |
| ✅ | metadata-mp4 | ✓ input had metadata 4 tags e.g. ItemList:Title, ItemList:Encoder, ItemList:Comment, ItemList:Copyright · ✓ nothing from the original left · ✓ audio packets identical 1876 packets · ✓ video packets identical 600 packets | ✅ |
| ✅ | metadata-mov | ✓ input had metadata 5 tags e.g. UserData:Title, UserData:SoftwareVersion, UserData:UserData_des, UserData:Comment · ✓ nothing from the original left · ✓ audio packets identical 1876 packets · ✓ video packets identical 600 packets | ✅ |
| ✅ | metadata-mkv | ✓ input had metadata 4 tags e.g. Matroska:Title, Matroska:Comment, Matroska:Copyright, Matroska:Encoder · ✓ nothing from the original left · ✓ audio packets identical 1876 packets · ✓ video packets identical 600 packets | ✅ |
| ✅ | metadata-pdf | ✓ input had metadata 14 tags e.g. PDF:Author, PDF:CreateDate, PDF:Creator, PDF:Producer · ✓ nothing from the original left · ✓ note: written by the OS writer, not from your file PDF:CreateDate=2026:10:19 12:44:01Z, PDF:Producer=macOS Version 26.6.2 (Build 25G83) Quartz PDFContext · ✓ same pages + text · ✓ PDF Info: no original values | ✅ |
| ✅ | metadata-gif | ✓ input had metadata 1 tags e.g. File:Comment · ✓ nothing from the original left · ✓ pixels identical lossless strip | ✅ |

## Crop Image — 7/7

| | Case | Checks | Fake caught |
|---|---|---|---|
| ✅ | crop-jpg-1x1 | ✓ dimensions 1920x1920 (want 1920x1920) · ✓ pixels = requested region luma PSNR 47.8 dB (≥35) | ✅ |
| ✅ | crop-jpg-16x9 | ✓ dimensions 2560x1440 (want 2560x1440) · ✓ pixels = requested region luma PSNR 47.9 dB (≥35) | ✅ |
| ✅ | crop-jpg-rect | ✓ dimensions 1200x900 (want 1200x900) · ✓ pixels = requested region luma PSNR 47.6 dB (≥35) | ✅ |
| ✅ | crop-jpg-rect-resize | ✓ dimensions 800x600 (want 800x600) · ✓ pixels = requested region luma PSNR 49.1 dB (≥30) | ✅ |
| ✅ | crop-png-3x4 | ✓ dimensions 1440x1920 (want 1440x1920) · ✓ pixels = requested region luma PSNR 99.0 dB (≥35) | ✅ |
| ✅ | crop-heic-9x16 | ✓ dimensions 1080x1920 (want 1080x1920) · ✓ pixels = requested region luma PSNR 52.3 dB (≥35) | ✅ |
| ✅ | crop-batch-2-jpgs | jellyfish-panasonic-gps Cropped.jpg: ✓ dimensions 1920x1920 (want 1920x1920) · ✓ pixels = requested region luma PSNR 47.8 dB (≥35) / jellyfish-panasonic-gps Cropped.png: ✓ dimensions 1920x1920 (want 1920x1920) · ✓ pixels = requested region luma PSNR 99.0 dB (≥35) | ✅ |

## Trim Video — 4/4

| | Case | Checks | Fake caught |
|---|---|---|---|
| ✅ | trim-mp4 | ✓ duration 15.500s (want 15.500s ±0.12) · ✓ frames = source from start luma PSNR 99.0 dB (≥35, offset +0 frames) · ✓ lossless (video packets copied) 263/263 packets found in source | ✅ |
| ✅ | trim-mov | ✓ duration 15.500s (want 15.500s ±0.12) · ✓ frames = source from start luma PSNR 99.0 dB (≥35, offset +0 frames) · ✓ lossless (video packets copied) 263/263 packets found in source | ✅ |
| ✅ | trim-mkv-keyframe | ✓ duration 12.031s (want 12.000s ±0.12) · ✓ frames = source from start luma PSNR 99.0 dB (≥35, offset +0 frames) · ✓ lossless (video packets copied) 180/180 packets found in source | ✅ |
| ✅ | trim-mkv-midgop | ✓ duration 15.221s (want 15.200s ±0.12) · ✓ frames = source from start luma PSNR 49.9 dB (≥35, offset +0 frames) · ✓ re-encoded (start not on a keyframe, as the window states) 0/227 packets reused | ✅ |

## Trim Audio — 6/6

| | Case | Checks | Fake caught |
|---|---|---|---|
| ✅ | trim-wav | ✓ duration 8.000s (want 8.000s ±0.02) · ✓ samples = source slice (lossless) exact match at start 2.0000s | ✅ |
| ✅ | trim-flac | ✓ duration 8.000s (want 8.000s ±0.02) · ✓ samples = source slice (lossless) exact match at start 2.0000s | ✅ |
| ✅ | trim-mp3 | ✓ duration 7.981s (want 8.000s ±0.06) · ✓ packets copied from source (no re-encode) 305/306 packets found in source | ✅ |
| ✅ | trim-m4a | ✓ duration 8.031s (want 8.000s ±0.06) · ✓ packets copied from source (no re-encode) 87/88 packets found in source | ✅ |
| ✅ | trim-wav-auto-silence-none | ✓ duration 24.113s (want 24.113s ±0.02) · ✓ samples = source slice (lossless) exact match at start 0.0000s · ✓ nothing to trim (edges aren't silent) edge peak -13.2 dBFS | — |
| ✅ | trim-wav-auto-silence-padded | ✓ duration 24.150s (want 24.150s ±0.02) · ✓ samples = source slice (lossless) exact match at start 1.4810s · ✓ removed parts are silent removed 1.48s + 1.48s, peak -90.3 dBFS (≤−45) · ✓ added silence removed removed 1.48s / 1.48s of the 1.5s added at each end | ✅ |

## Remove Audio — 3/3

| | Case | Checks | Fake caught |
|---|---|---|---|
| ✅ | mute-mp4 | ✓ no audio 1 stream(s) left · ✓ video packets identical (no re-encode) 600 packets | ✅ |
| ✅ | mute-mov | ✓ no audio 1 stream(s) left · ✓ video packets identical (no re-encode) 600 packets | ✅ |
| ✅ | mute-mkv | ✓ no audio 1 stream(s) left · ✓ video packets identical (no re-encode) 600 packets | ✅ |

## Extract — 5/5

| | Case | Checks | Fake caught |
|---|---|---|---|
| ✅ | extract-tar-gz | ✓ same files 326 files (archive: 326) · ✓ identical content (SHA-256) all match | ✅ |
| ✅ | extract-tar | ✓ same files 326 files (archive: 326) · ✓ identical content (SHA-256) all match | ✅ |
| ✅ | extract-zip | ✓ same files 134 files (archive: 134) · ✓ identical content (SHA-256) all match | ✅ |
| ✅ | extract-rar | ✓ same files 3 files (archive: 3) · ✓ identical content (SHA-256) all match | ✅ |
| ✅ | extract-traversal-zip | ✓ nothing written outside the folder · Morph exit 1: FAIL: “traversal.zip” contains files that would be written outside the destination folder, so Morph didn't extract it. Nothing was written. | — |

