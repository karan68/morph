# Independent conversion verification

Verified on Linux with tools that did **not** produce the files: ffmpeg version 6.1.1-3ubuntu5 Copyright (c) 2000-2023 the FFmpeg developers; file-5.45; Pillow 10.2.0; libheif 1.17.6; rsvg-convert version 2.58.0; poppler pdftoppm; Ubuntu bsdtar; Python zipfile/tarfile.

- **Real conversions: 174 / 174** (signature ✓ · not a rename ✓ · full decode ✓ · content matches source ✓)
- **Rename controls caught: 174 / 174** — every input copied to the target extension (a fake “conversion”) was rejected

| | Path | Bytes say | libmagic | Not rename | Decodes | Content check |
|---|---|---|---|---|---|---|
| ✅ | aiff→mp3 | mp3 (input: aiff) | audio/mpeg | ✅ | ✅ | mp3 · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | aiff→m4a | m4a (input: aiff) | audio/x-m4a | ✅ | ✅ | aac · tone 440 Hz (src 440) · 3.02s (src 3.00s) |
| ✅ | aiff→wav | wav (input: aiff) | audio/x-wav | ✅ | ✅ | pcm_s16le · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | aiff→flac | flac (input: aiff) | audio/flac | ✅ | ✅ | flac · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | aiff→ogg | ogg (input: aiff) | audio/ogg | ✅ | ✅ | vorbis · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | aiff→opus | opus (input: aiff) | audio/ogg | ✅ | ✅ | opus · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | aiff→wma | asf (input: aiff) | video/x-ms-asf | ✅ | ✅ | wmav2 · tone 440 Hz (src 440) · 2.97s (src 3.00s) |
| ✅ | avi→mp4 | mp4 (input: avi) | video/mp4 | ✅ | ✅ | h264 320x240 · 90 frames, mean luma PSNR 45.8 dB (≥35, offset +0) · 3.03s (src 3.03s) · tone 330 Hz (src 330) |
| ✅ | avi→mov | mov (input: avi) | video/quicktime | ✅ | ✅ | h264 320x240 · 90 frames, mean luma PSNR 45.8 dB (≥35, offset +0) · 3.03s (src 3.03s) · tone 330 Hz (src 330) |
| ✅ | avi→mkv | mkv (input: avi) | video/x-matroska | ✅ | ✅ | h264 320x240 · 90 frames, mean luma PSNR 45.9 dB (≥35, offset -1) · 3.05s (src 3.03s) · tone 330 Hz (src 330) |
| ✅ | avi→webm | webm (input: avi) | video/webm | ✅ | ✅ | vp9 320x240 · 90 frames, mean luma PSNR 42.3 dB (≥35, offset +0) · 3.04s (src 3.03s) · tone 330 Hz (src 330) |
| ✅ | avi→wmv | asf (input: avi) | video/x-ms-asf | ✅ | ✅ | wmv2 320x240 · 90 frames, mean luma PSNR 48.1 dB (≥35, offset -1) · 3.12s (src 3.03s) · tone 330 Hz (src 330) |
| ✅ | avi→gif | gif (input: avi) | image/gif | ✅ | ✅ | gif 320x240 · 36 frames, mean luma PSNR 40.5 dB (≥25, offset +0) · 3.00s (src 3.03s) |
| ✅ | avi→mp3 | mp3 (input: avi) | audio/mpeg | ✅ | ✅ | mp3 · tone 330 Hz (src 330) · 3.03s (src 3.03s) |
| ✅ | avif→jpg | jpg (input: avif) | image/jpeg | ✅ | ✅ | 640x480 · luma PSNR 45.6 dB (≥35) · mean colour Δ 0.1 (≤4) |
| ✅ | avif→png | png (input: avif) | image/png | ✅ | ✅ | 640x480 · luma PSNR 50.0 dB (≥35) · mean colour Δ 0.1 (≤4) |
| ✅ | avif→webp | webp (input: avif) | image/webp | ✅ | ✅ | 640x480 · luma PSNR 45.1 dB (≥35) · mean colour Δ 0.5 (≤4) |
| ✅ | avif→heic | heic (input: avif) | image/heic | ✅ | ✅ | 640x480 · luma PSNR 60.1 dB (≥35) · mean colour Δ 0.0 (≤4) |
| ✅ | avif→tiff | tiff (input: avif) | image/tiff | ✅ | ✅ | 640x480 · luma PSNR 50.0 dB (≥35) · mean colour Δ 0.1 (≤4) |
| ✅ | avif→bmp | bmp (input: avif) | image/bmp | ✅ | ✅ | 640x480 · luma PSNR 50.0 dB (≥35) · mean colour Δ 0.1 (≤4) |
| ✅ | avif→pdf | pdf (input: avif) | application/pdf | ✅ | ✅ | 640x480 · luma PSNR 49.9 dB (≥35) · mean colour Δ 0.2 (≤4) |
| ✅ | bmp→jpg | jpg (input: bmp) | image/jpeg | ✅ | ✅ | 640x480 · luma PSNR 48.4 dB (≥35) · mean colour Δ 0.1 (≤4) |
| ✅ | bmp→png | png (input: bmp) | image/png | ✅ | ✅ | 640x480 · luma PSNR 99.0 dB (≥35) · mean colour Δ 0.0 (≤4) |
| ✅ | bmp→webp | webp (input: bmp) | image/webp | ✅ | ✅ | 640x480 · luma PSNR 47.6 dB (≥35) · mean colour Δ 0.5 (≤4) |
| ✅ | bmp→heic | heic (input: bmp) | image/heic | ✅ | ✅ | 640x480 · luma PSNR 56.0 dB (≥35) · mean colour Δ 0.3 (≤4) |
| ✅ | bmp→tiff | tiff (input: bmp) | image/tiff | ✅ | ✅ | 640x480 · luma PSNR 99.0 dB (≥35) · mean colour Δ 0.0 (≤4) |
| ✅ | bmp→avif | avif (input: bmp) | image/avif | ✅ | ✅ | 640x480 · luma PSNR 55.7 dB (≥35) · mean colour Δ 0.3 (≤4) |
| ✅ | bmp→pdf | pdf (input: bmp) | application/pdf | ✅ | ✅ | 640x480 · luma PSNR 66.6 dB (≥35) · mean colour Δ 0.2 (≤4) |
| ✅ | flac→mp3 | mp3 (input: flac) | audio/mpeg | ✅ | ✅ | mp3 · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | flac→m4a | m4a (input: flac) | audio/x-m4a | ✅ | ✅ | aac · tone 440 Hz (src 440) · 3.02s (src 3.00s) |
| ✅ | flac→wav | wav (input: flac) | audio/x-wav | ✅ | ✅ | pcm_s16le · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | flac→ogg | ogg (input: flac) | audio/ogg | ✅ | ✅ | vorbis · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | flac→opus | opus (input: flac) | audio/ogg | ✅ | ✅ | opus · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | flac→aiff | aiff (input: flac) | audio/x-aiff | ✅ | ✅ | pcm_s16be · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | flac→wma | asf (input: flac) | video/x-ms-asf | ✅ | ✅ | wmav2 · tone 440 Hz (src 440) · 2.97s (src 3.00s) |
| ✅ | gif→mp4 | mp4 (input: gif) | video/mp4 | ✅ | ✅ | h264 240x180 · 20 frames, mean luma PSNR 49.7 dB (≥25, offset +0) · 2.00s (src 2.00s) |
| ✅ | gif→mov | mov (input: gif) | video/quicktime | ✅ | ✅ | h264 240x180 · 20 frames, mean luma PSNR 49.7 dB (≥25, offset +0) · 2.00s (src 2.00s) |
| ✅ | gif→mkv | mkv (input: gif) | video/x-matroska | ✅ | ✅ | h264 240x180 · 20 frames, mean luma PSNR 49.7 dB (≥25, offset +0) · 2.00s (src 2.00s) |
| ✅ | gif→webm | webm (input: gif) | video/webm | ✅ | ✅ | vp9 240x180 · 20 frames, mean luma PSNR 38.7 dB (≥25, offset +0) · 2.00s (src 2.00s) |
| ✅ | gif→avi | avi (input: gif) | video/x-msvideo | ✅ | ✅ | mpeg4 240x180 · 20 frames, mean luma PSNR 40.7 dB (≥25, offset +0) · 2.00s (src 2.00s) |
| ✅ | gif→wmv | asf (input: gif) | video/x-ms-asf | ✅ | ✅ | wmv2 240x180 · 20 frames, mean luma PSNR 40.8 dB (≥25, offset +0) · 2.00s (src 2.00s) |
| ✅ | gz→zip | zip (input: gz) | application/zip | ✅ | ✅ | 2 entries, names + SHA-256 (and symlink targets) identical to source |
| ✅ | gz→tar | tar (input: gz) | application/x-tar | ✅ | ✅ | 2 entries, names + SHA-256 (and symlink targets) identical to source |
| ✅ | heic→jpg | jpg (input: heic) | image/jpeg | ✅ | ✅ | 640x480 · luma PSNR 45.5 dB (≥35) · mean colour Δ 0.1 (≤4) |
| ✅ | heic→png | png (input: heic) | image/png | ✅ | ✅ | 640x480 · luma PSNR 49.7 dB (≥35) · mean colour Δ 0.1 (≤4) |
| ✅ | heic→webp | webp (input: heic) | image/webp | ✅ | ✅ | 640x480 · luma PSNR 45.0 dB (≥35) · mean colour Δ 0.5 (≤4) |
| ✅ | heic→tiff | tiff (input: heic) | image/tiff | ✅ | ✅ | 640x480 · luma PSNR 49.7 dB (≥35) · mean colour Δ 0.1 (≤4) |
| ✅ | heic→avif | avif (input: heic) | image/avif | ✅ | ✅ | 640x480 · luma PSNR 59.0 dB (≥35) · mean colour Δ 0.0 (≤4) |
| ✅ | heic→bmp | bmp (input: heic) | image/bmp | ✅ | ✅ | 640x480 · luma PSNR 49.7 dB (≥35) · mean colour Δ 0.1 (≤4) |
| ✅ | heic→pdf | pdf (input: heic) | application/pdf | ✅ | ✅ | 640x480 · luma PSNR 49.7 dB (≥35) · mean colour Δ 0.2 (≤4) |
| ✅ | jpg→png | png (input: jpg) | image/png | ✅ | ✅ | 640x480 · luma PSNR 94.8 dB (≥35) · mean colour Δ 0.0 (≤4) |
| ✅ | jpg→webp | webp (input: jpg) | image/webp | ✅ | ✅ | 640x480 · luma PSNR 47.5 dB (≥35) · mean colour Δ 0.5 (≤4) |
| ✅ | jpg→heic | heic (input: jpg) | image/heic | ✅ | ✅ | 640x480 · luma PSNR 56.4 dB (≥35) · mean colour Δ 0.0 (≤4) |
| ✅ | jpg→tiff | tiff (input: jpg) | image/tiff | ✅ | ✅ | 640x480 · luma PSNR 94.8 dB (≥35) · mean colour Δ 0.0 (≤4) |
| ✅ | jpg→avif | avif (input: jpg) | image/avif | ✅ | ✅ | 640x480 · luma PSNR 56.1 dB (≥35) · mean colour Δ 0.0 (≤4) |
| ✅ | jpg→bmp | bmp (input: jpg) | image/bmp | ✅ | ✅ | 640x480 · luma PSNR 94.8 dB (≥35) · mean colour Δ 0.0 (≤4) |
| ✅ | jpg→pdf | pdf (input: jpg) | application/pdf | ✅ | ✅ | 640x480 · luma PSNR 66.8 dB (≥35) · mean colour Δ 0.2 (≤4) |
| ✅ | m4a→mp3 | mp3 (input: m4a) | audio/mpeg | ✅ | ✅ | mp3 · tone 440 Hz (src 440) · 3.02s (src 3.02s) |
| ✅ | m4a→wav | wav (input: m4a) | audio/x-wav | ✅ | ✅ | pcm_s16le · tone 440 Hz (src 440) · 3.00s (src 3.02s) |
| ✅ | m4a→flac | flac (input: m4a) | audio/flac | ✅ | ✅ | flac · tone 440 Hz (src 440) · 3.00s (src 3.02s) |
| ✅ | m4a→ogg | ogg (input: m4a) | audio/ogg | ✅ | ✅ | vorbis · tone 440 Hz (src 440) · 3.02s (src 3.02s) |
| ✅ | m4a→opus | opus (input: m4a) | audio/ogg | ✅ | ✅ | opus · tone 440 Hz (src 440) · 3.02s (src 3.02s) |
| ✅ | m4a→aiff | aiff (input: m4a) | audio/x-aiff | ✅ | ✅ | pcm_s16be · tone 440 Hz (src 440) · 3.00s (src 3.02s) |
| ✅ | m4a→wma | asf (input: m4a) | video/x-ms-asf | ✅ | ✅ | wmav2 · tone 440 Hz (src 440) · 2.97s (src 3.02s) |
| ✅ | mkv→mp4 | mp4 (input: mkv) | video/mp4 | ✅ | ✅ | h264 320x240 · 90 frames, mean luma PSNR 55.5 dB (≥35, offset +0) · 3.04s (src 3.02s) · tone 330 Hz (src 330) |
| ✅ | mkv→mov | mov (input: mkv) | video/quicktime | ✅ | ✅ | h264 320x240 · 90 frames, mean luma PSNR 55.5 dB (≥35, offset +0) · 3.04s (src 3.02s) · tone 330 Hz (src 330) |
| ✅ | mkv→webm | webm (input: mkv) | video/webm | ✅ | ✅ | vp9 320x240 · 90 frames, mean luma PSNR 43.0 dB (≥35, offset +0) · 3.05s (src 3.02s) · tone 330 Hz (src 330) |
| ✅ | mkv→avi | avi (input: mkv) | video/x-msvideo | ✅ | ✅ | mpeg4 320x240 · 90 frames, mean luma PSNR 45.8 dB (≥35, offset -1) · 3.08s (src 3.02s) · tone 330 Hz (src 330) |
| ✅ | mkv→wmv | asf (input: mkv) | video/x-ms-asf | ✅ | ✅ | wmv2 320x240 · 90 frames, mean luma PSNR 46.0 dB (≥35, offset -1) · 3.12s (src 3.02s) · tone 330 Hz (src 330) |
| ✅ | mkv→gif | gif (input: mkv) | image/gif | ✅ | ✅ | gif 320x240 · 36 frames, mean luma PSNR 44.7 dB (≥25, offset +0) · 3.00s (src 3.02s) |
| ✅ | mkv→mp3 | mp3 (input: mkv) | audio/mpeg | ✅ | ✅ | mp3 · tone 330 Hz (src 330) · 3.04s (src 3.04s) |
| ✅ | mov→mp4 | mp4 (input: mov) | video/mp4 | ✅ | ✅ | h264 320x240 · 90 frames, mean luma PSNR 99.0 dB (≥35, offset +0) · 3.00s (src 3.00s) · tone 330 Hz (src 330) |
| ✅ | mov→mkv | mkv (input: mov) | video/x-matroska | ✅ | ✅ | h264 320x240 · 90 frames, mean luma PSNR 55.5 dB (≥35, offset -1) · 3.04s (src 3.00s) · tone 330 Hz (src 330) |
| ✅ | mov→webm | webm (input: mov) | video/webm | ✅ | ✅ | vp9 320x240 · 90 frames, mean luma PSNR 42.9 dB (≥35, offset +0) · 3.03s (src 3.00s) · tone 330 Hz (src 330) |
| ✅ | mov→avi | avi (input: mov) | video/x-msvideo | ✅ | ✅ | mpeg4 320x240 · 90 frames, mean luma PSNR 46.0 dB (≥35, offset -1) · 3.06s (src 3.00s) · tone 330 Hz (src 330) |
| ✅ | mov→wmv | asf (input: mov) | video/x-ms-asf | ✅ | ✅ | wmv2 320x240 · 90 frames, mean luma PSNR 46.1 dB (≥35, offset -1) · 3.09s (src 3.00s) · tone 330 Hz (src 330) |
| ✅ | mov→gif | gif (input: mov) | image/gif | ✅ | ✅ | gif 320x240 · 36 frames, mean luma PSNR 44.7 dB (≥25, offset +0) · 3.00s (src 3.00s) |
| ✅ | mov→mp3 | mp3 (input: mov) | audio/mpeg | ✅ | ✅ | mp3 · tone 330 Hz (src 330) · 3.02s (src 3.02s) |
| ✅ | mp3→m4a | m4a (input: mp3) | audio/x-m4a | ✅ | ✅ | aac · tone 440 Hz (src 440) · 3.02s (src 3.00s) |
| ✅ | mp3→wav | wav (input: mp3) | audio/x-wav | ✅ | ✅ | pcm_s16le · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | mp3→flac | flac (input: mp3) | audio/flac | ✅ | ✅ | flac · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | mp3→ogg | ogg (input: mp3) | audio/ogg | ✅ | ✅ | vorbis · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | mp3→opus | opus (input: mp3) | audio/ogg | ✅ | ✅ | opus · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | mp3→aiff | aiff (input: mp3) | audio/x-aiff | ✅ | ✅ | pcm_s16be · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | mp3→wma | asf (input: mp3) | video/x-ms-asf | ✅ | ✅ | wmav2 · tone 440 Hz (src 440) · 2.97s (src 3.00s) |
| ✅ | mp4→mov | mov (input: mp4) | video/quicktime | ✅ | ✅ | h264 320x240 · 90 frames, mean luma PSNR 99.0 dB (≥35, offset +0) · 3.00s (src 3.00s) · tone 330 Hz (src 330) |
| ✅ | mp4→mkv | mkv (input: mp4) | video/x-matroska | ✅ | ✅ | h264 320x240 · 90 frames, mean luma PSNR 55.5 dB (≥35, offset -1) · 3.04s (src 3.00s) · tone 330 Hz (src 330) |
| ✅ | mp4→webm | webm (input: mp4) | video/webm | ✅ | ✅ | vp9 320x240 · 90 frames, mean luma PSNR 42.9 dB (≥35, offset +0) · 3.03s (src 3.00s) · tone 330 Hz (src 330) |
| ✅ | mp4→avi | avi (input: mp4) | video/x-msvideo | ✅ | ✅ | mpeg4 320x240 · 90 frames, mean luma PSNR 46.0 dB (≥35, offset -1) · 3.06s (src 3.00s) · tone 330 Hz (src 330) |
| ✅ | mp4→wmv | asf (input: mp4) | video/x-ms-asf | ✅ | ✅ | wmv2 320x240 · 90 frames, mean luma PSNR 46.1 dB (≥35, offset -1) · 3.09s (src 3.00s) · tone 330 Hz (src 330) |
| ✅ | mp4→gif | gif (input: mp4) | image/gif | ✅ | ✅ | gif 320x240 · 36 frames, mean luma PSNR 44.7 dB (≥25, offset +0) · 3.00s (src 3.00s) |
| ✅ | mp4→mp3 | mp3 (input: mp4) | audio/mpeg | ✅ | ✅ | mp3 · tone 330 Hz (src 330) · 3.02s (src 3.02s) |
| ✅ | ogg→mp3 | mp3 (input: ogg) | audio/mpeg | ✅ | ✅ | mp3 · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | ogg→m4a | m4a (input: ogg) | audio/x-m4a | ✅ | ✅ | aac · tone 440 Hz (src 440) · 3.02s (src 3.00s) |
| ✅ | ogg→wav | wav (input: ogg) | audio/x-wav | ✅ | ✅ | pcm_s16le · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | ogg→flac | flac (input: ogg) | audio/flac | ✅ | ✅ | flac · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | ogg→opus | opus (input: ogg) | audio/ogg | ✅ | ✅ | opus · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | ogg→aiff | aiff (input: ogg) | audio/x-aiff | ✅ | ✅ | pcm_s16be · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | ogg→wma | asf (input: ogg) | video/x-ms-asf | ✅ | ✅ | wmav2 · tone 440 Hz (src 440) · 2.97s (src 3.00s) |
| ✅ | opus→mp3 | mp3 (input: opus) | audio/mpeg | ✅ | ✅ | mp3 · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | opus→m4a | m4a (input: opus) | audio/x-m4a | ✅ | ✅ | aac · tone 440 Hz (src 440) · 3.01s (src 3.00s) |
| ✅ | opus→wav | wav (input: opus) | audio/x-wav | ✅ | ✅ | pcm_s16le · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | opus→flac | flac (input: opus) | audio/flac | ✅ | ✅ | flac · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | opus→ogg | ogg (input: opus) | audio/ogg | ✅ | ✅ | vorbis · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | opus→aiff | aiff (input: opus) | audio/x-aiff | ✅ | ✅ | pcm_s16be · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | opus→wma | asf (input: opus) | video/x-ms-asf | ✅ | ✅ | wmav2 · tone 440 Hz (src 440) · 2.99s (src 3.00s) |
| ✅ | png→jpg | jpg (input: png) | image/jpeg | ✅ | ✅ | 640x480 · luma PSNR 48.4 dB (≥35) · mean colour Δ 0.1 (≤4) |
| ✅ | png→webp | webp (input: png) | image/webp | ✅ | ✅ | 640x480 · luma PSNR 47.6 dB (≥35) · mean colour Δ 0.5 (≤4) |
| ✅ | png→heic | heic (input: png) | image/heic | ✅ | ✅ | 640x480 · luma PSNR 56.0 dB (≥35) · mean colour Δ 0.3 (≤4) |
| ✅ | png→tiff | tiff (input: png) | image/tiff | ✅ | ✅ | 640x480 · luma PSNR 99.0 dB (≥35) · mean colour Δ 0.0 (≤4) |
| ✅ | png→avif | avif (input: png) | image/avif | ✅ | ✅ | 640x480 · luma PSNR 55.7 dB (≥35) · mean colour Δ 0.3 (≤4) |
| ✅ | png→bmp | bmp (input: png) | image/bmp | ✅ | ✅ | 640x480 · luma PSNR 99.0 dB (≥35) · mean colour Δ 0.0 (≤4) |
| ✅ | png→pdf | pdf (input: png) | application/pdf | ✅ | ✅ | 640x480 · luma PSNR 66.6 dB (≥35) · mean colour Δ 0.2 (≤4) |
| ✅ | rar→zip | zip (input: rar) | application/zip | ✅ | ✅ | 3 entries, names + SHA-256 (and symlink targets) identical to source |
| ✅ | rar→tar | tar (input: rar) | application/x-tar | ✅ | ✅ | 3 entries, names + SHA-256 (and symlink targets) identical to source |
| ✅ | rar→gz | gz (input: rar) | application/gzip | ✅ | ✅ | 3 entries, names + SHA-256 (and symlink targets) identical to source |
| ✅ | srt→vtt | vtt (input: srt) | text/vtt | ✅ | ✅ | 2 cues, identical timings + text |
| ✅ | srt→txt | txt (input: srt) | text/plain | ✅ | ✅ | 2 text lines = cue text, no timestamps |
| ✅ | svg→jpg | jpg (input: svg) | image/jpeg | ✅ | ✅ | 200x120 · luma PSNR 48.8 dB (≥25) · mean colour Δ 0.5 (≤4) |
| ✅ | svg→png | png (input: svg) | image/png | ✅ | ✅ | 200x120 · luma PSNR 66.1 dB (≥25) · mean colour Δ 0.0 (≤4) |
| ✅ | svg→webp | webp (input: svg) | image/webp | ✅ | ✅ | 200x120 · luma PSNR 50.9 dB (≥25) · mean colour Δ 1.5 (≤4) |
| ✅ | svg→heic | heic (input: svg) | image/heic | ✅ | ✅ | 200x120 · luma PSNR 54.7 dB (≥25) · mean colour Δ 0.9 (≤4) |
| ✅ | svg→tiff | tiff (input: svg) | image/tiff | ✅ | ✅ | 200x120 · luma PSNR 65.7 dB (≥25) · mean colour Δ 0.0 (≤4) |
| ✅ | svg→avif | avif (input: svg) | image/avif | ✅ | ✅ | 200x120 · luma PSNR 56.6 dB (≥25) · mean colour Δ 0.8 (≤4) |
| ✅ | svg→bmp | bmp (input: svg) | image/bmp | ✅ | ✅ | 200x120 · luma PSNR 66.1 dB (≥25) · mean colour Δ 0.0 (≤4) |
| ✅ | svg→pdf | pdf (input: svg) | application/pdf | ✅ | ✅ | 200x120 · luma PSNR 66.1 dB (≥25) · mean colour Δ 0.0 (≤4) |
| ✅ | tar→zip | zip (input: tar) | application/zip | ✅ | ✅ | 2 entries, names + SHA-256 (and symlink targets) identical to source |
| ✅ | tar→gz | gz (input: tar) | application/gzip | ✅ | ✅ | 2 entries, names + SHA-256 (and symlink targets) identical to source |
| ✅ | tiff→jpg | jpg (input: tiff) | image/jpeg | ✅ | ✅ | 640x480 · luma PSNR 48.4 dB (≥35) · mean colour Δ 0.1 (≤4) |
| ✅ | tiff→png | png (input: tiff) | image/png | ✅ | ✅ | 640x480 · luma PSNR 99.0 dB (≥35) · mean colour Δ 0.0 (≤4) |
| ✅ | tiff→webp | webp (input: tiff) | image/webp | ✅ | ✅ | 640x480 · luma PSNR 47.6 dB (≥35) · mean colour Δ 0.5 (≤4) |
| ✅ | tiff→heic | heic (input: tiff) | image/heic | ✅ | ✅ | 640x480 · luma PSNR 56.0 dB (≥35) · mean colour Δ 0.3 (≤4) |
| ✅ | tiff→avif | avif (input: tiff) | image/avif | ✅ | ✅ | 640x480 · luma PSNR 55.7 dB (≥35) · mean colour Δ 0.3 (≤4) |
| ✅ | tiff→bmp | bmp (input: tiff) | image/bmp | ✅ | ✅ | 640x480 · luma PSNR 99.0 dB (≥35) · mean colour Δ 0.0 (≤4) |
| ✅ | tiff→pdf | pdf (input: tiff) | application/pdf | ✅ | ✅ | 640x480 · luma PSNR 66.6 dB (≥35) · mean colour Δ 0.2 (≤4) |
| ✅ | vtt→srt | srt (input: vtt) | application/x-subrip | ✅ | ✅ | 2 cues, identical timings + text |
| ✅ | vtt→txt | txt (input: vtt) | text/plain | ✅ | ✅ | 2 text lines = cue text, no timestamps |
| ✅ | wav→mp3 | mp3 (input: wav) | audio/mpeg | ✅ | ✅ | mp3 · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | wav→m4a | m4a (input: wav) | audio/x-m4a | ✅ | ✅ | aac · tone 440 Hz (src 440) · 3.02s (src 3.00s) |
| ✅ | wav→flac | flac (input: wav) | audio/flac | ✅ | ✅ | flac · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | wav→ogg | ogg (input: wav) | audio/ogg | ✅ | ✅ | vorbis · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | wav→opus | opus (input: wav) | audio/ogg | ✅ | ✅ | opus · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | wav→aiff | aiff (input: wav) | audio/x-aiff | ✅ | ✅ | pcm_s16be · tone 440 Hz (src 440) · 3.00s (src 3.00s) |
| ✅ | wav→wma | asf (input: wav) | video/x-ms-asf | ✅ | ✅ | wmav2 · tone 440 Hz (src 440) · 2.97s (src 3.00s) |
| ✅ | webm→mp4 | mp4 (input: webm) | video/mp4 | ✅ | ✅ | h264 320x240 · 90 frames, mean luma PSNR 44.9 dB (≥35, offset +0) · 3.01s (src 3.01s) · tone 330 Hz (src 330) |
| ✅ | webm→mov | mov (input: webm) | video/quicktime | ✅ | ✅ | h264 320x240 · 90 frames, mean luma PSNR 44.9 dB (≥35, offset +0) · 3.01s (src 3.01s) · tone 330 Hz (src 330) |
| ✅ | webm→mkv | mkv (input: webm) | video/x-matroska | ✅ | ✅ | h264 320x240 · 90 frames, mean luma PSNR 44.9 dB (≥35, offset +0) · 3.03s (src 3.01s) · tone 330 Hz (src 330) |
| ✅ | webm→avi | avi (input: webm) | video/x-msvideo | ✅ | ✅ | mpeg4 320x240 · 90 frames, mean luma PSNR 45.4 dB (≥35, offset -1) · 3.03s (src 3.01s) · tone 330 Hz (src 330) |
| ✅ | webm→wmv | asf (input: webm) | video/x-ms-asf | ✅ | ✅ | wmv2 320x240 · 90 frames, mean luma PSNR 45.5 dB (≥35, offset -1) · 3.07s (src 3.01s) · tone 330 Hz (src 330) |
| ✅ | webm→gif | gif (input: webm) | image/gif | ✅ | ✅ | gif 320x240 · 36 frames, mean luma PSNR 38.3 dB (≥25, offset +0) · 3.00s (src 3.01s) |
| ✅ | webm→mp3 | mp3 (input: webm) | audio/mpeg | ✅ | ✅ | mp3 · tone 330 Hz (src 330) · 3.00s (src 3.00s) |
| ✅ | webp→jpg | jpg (input: webp) | image/jpeg | ✅ | ✅ | 640x480 · luma PSNR 51.5 dB (≥35) · mean colour Δ 0.3 (≤4) |
| ✅ | webp→png | png (input: webp) | image/png | ✅ | ✅ | 640x480 · luma PSNR 99.0 dB (≥35) · mean colour Δ 0.0 (≤4) |
| ✅ | webp→heic | heic (input: webp) | image/heic | ✅ | ✅ | 640x480 · luma PSNR 56.1 dB (≥35) · mean colour Δ 0.2 (≤4) |
| ✅ | webp→tiff | tiff (input: webp) | image/tiff | ✅ | ✅ | 640x480 · luma PSNR 99.0 dB (≥35) · mean colour Δ 0.0 (≤4) |
| ✅ | webp→avif | avif (input: webp) | image/avif | ✅ | ✅ | 640x480 · luma PSNR 55.3 dB (≥35) · mean colour Δ 0.2 (≤4) |
| ✅ | webp→bmp | bmp (input: webp) | image/bmp | ✅ | ✅ | 640x480 · luma PSNR 99.0 dB (≥35) · mean colour Δ 0.0 (≤4) |
| ✅ | webp→pdf | pdf (input: webp) | application/pdf | ✅ | ✅ | 640x480 · luma PSNR 66.8 dB (≥35) · mean colour Δ 0.2 (≤4) |
| ✅ | wma→mp3 | mp3 (input: asf) | audio/mpeg | ✅ | ✅ | mp3 · tone 440 Hz (src 440) · 2.97s (src 2.97s) |
| ✅ | wma→m4a | m4a (input: asf) | audio/x-m4a | ✅ | ✅ | aac · tone 440 Hz (src 440) · 3.00s (src 2.97s) |
| ✅ | wma→wav | wav (input: asf) | audio/x-wav | ✅ | ✅ | pcm_s16le · tone 440 Hz (src 440) · 2.97s (src 2.97s) |
| ✅ | wma→flac | flac (input: asf) | audio/flac | ✅ | ✅ | flac · tone 440 Hz (src 440) · 2.97s (src 2.97s) |
| ✅ | wma→ogg | ogg (input: asf) | audio/ogg | ✅ | ✅ | vorbis · tone 440 Hz (src 440) · 2.97s (src 2.97s) |
| ✅ | wma→opus | opus (input: asf) | audio/ogg | ✅ | ✅ | opus · tone 440 Hz (src 440) · 2.97s (src 2.97s) |
| ✅ | wma→aiff | aiff (input: asf) | audio/x-aiff | ✅ | ✅ | pcm_s16be · tone 440 Hz (src 440) · 2.97s (src 2.97s) |
| ✅ | wmv→mp4 | mp4 (input: asf) | video/mp4 | ✅ | ✅ | h264 320x240 · 90 frames, mean luma PSNR 46.6 dB (≥35, offset +1) · 3.03s (src 3.09s) · tone 330 Hz (src 330) |
| ✅ | wmv→mov | mov (input: asf) | video/quicktime | ✅ | ✅ | h264 320x240 · 90 frames, mean luma PSNR 46.6 dB (≥35, offset +1) · 3.03s (src 3.09s) · tone 330 Hz (src 330) |
| ✅ | wmv→mkv | mkv (input: asf) | video/x-matroska | ✅ | ✅ | h264 320x240 · 90 frames, mean luma PSNR 46.6 dB (≥35, offset +1) · 3.09s (src 3.09s) · tone 330 Hz (src 330) |
| ✅ | wmv→webm | webm (input: asf) | video/webm | ✅ | ✅ | vp9 320x240 · 90 frames, mean luma PSNR 42.3 dB (≥35, offset +1) · 3.07s (src 3.09s) · tone 330 Hz (src 330) |
| ✅ | wmv→avi | avi (input: asf) | video/x-msvideo | ✅ | ✅ | mpeg4 320x240 · 90 frames, mean luma PSNR 50.5 dB (≥35, offset +0) · 3.08s (src 3.09s) · tone 330 Hz (src 330) |
| ✅ | wmv→gif | gif (input: asf) | image/gif | ✅ | ✅ | gif 320x240 · 36 frames, mean luma PSNR 40.2 dB (≥25, offset +1) · 3.00s (src 3.09s) |
| ✅ | wmv→mp3 | mp3 (input: asf) | audio/mpeg | ✅ | ✅ | mp3 · tone 330 Hz (src 330) · 2.97s (src 2.97s) |
| ✅ | zip→tar | tar (input: zip) | application/x-tar | ✅ | ✅ | 2 entries, names + SHA-256 (and symlink targets) identical to source |
| ✅ | zip→gz | gz (input: zip) | application/gzip | ✅ | ✅ | 2 entries, names + SHA-256 (and symlink targets) identical to source |
