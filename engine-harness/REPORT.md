# Engine harness (Tokyo VM) — ffmpeg version 7.1 Copyright (c) 2000-2024 the FFmpeg developers

- Checks run on Linux: **113 / 113 passed**
- macOS-only (VideoToolbox, covered by the macOS CI golden matrix): 18 — mp4→mov, mp4→mkv, mov→mp4, mov→mkv, mkv→mp4, mkv→mov, webm→mp4, webm→mov, webm→mkv, avi→mp4, avi→mov, avi→mkv, wmv→mp4, wmv→mov, wmv→mkv, gif→mp4, gif→mov, gif→mkv

| Result | Group | Case | Seconds | Detail |
|---|---|---|---:|---|
| ✅ | audio | mp3→m4a | 0.29 | aac 3.00s |
| ✅ | audio | mp3→wav | 0.03 | pcm_s16le 3.00s |
| ✅ | audio | mp3→flac | 0.05 | flac 3.00s |
| ✅ | audio | mp3→ogg | 0.14 | vorbis 3.00s |
| ✅ | audio | mp3→opus | 0.1 | opus 3.01s |
| ✅ | audio | mp3→aiff | 0.03 | pcm_s16be 3.00s |
| ✅ | audio | mp3→wma | 0.05 | wmav2 3.00s |
| ✅ | audio | m4a→mp3 | 0.16 | mp3 3.06s |
| ✅ | audio | m4a→wav | 0.02 | pcm_s16le 3.02s |
| ✅ | audio | m4a→flac | 0.06 | flac 3.02s |
| ✅ | audio | m4a→ogg | 0.23 | vorbis 3.02s |
| ✅ | audio | m4a→opus | 0.09 | opus 3.03s |
| ✅ | audio | m4a→aiff | 0.02 | pcm_s16be 3.02s |
| ✅ | audio | m4a→wma | 0.04 | wmav2 3.02s |
| ✅ | audio | wav→mp3 | 0.2 | mp3 3.03s |
| ✅ | audio | wav→m4a | 0.29 | aac 3.00s |
| ✅ | audio | wav→flac | 0.09 | flac 3.00s |
| ✅ | audio | wav→ogg | 0.17 | vorbis 3.00s |
| ✅ | audio | wav→opus | 0.14 | opus 3.01s |
| ✅ | audio | wav→aiff | 0.07 | pcm_s16be 3.00s |
| ✅ | audio | wav→wma | 0.09 | wmav2 3.00s |
| ✅ | audio | flac→mp3 | 0.19 | mp3 3.03s |
| ✅ | audio | flac→m4a | 0.25 | aac 3.00s |
| ✅ | audio | flac→wav | 0.03 | pcm_s16le 3.00s |
| ✅ | audio | flac→ogg | 0.13 | vorbis 3.00s |
| ✅ | audio | flac→opus | 0.09 | opus 3.01s |
| ✅ | audio | flac→aiff | 0.02 | pcm_s16be 3.00s |
| ✅ | audio | flac→wma | 0.04 | wmav2 3.00s |
| ✅ | audio | ogg→mp3 | 0.15 | mp3 3.03s |
| ✅ | audio | ogg→m4a | 0.66 | aac 3.00s |
| ✅ | audio | ogg→wav | 0.02 | pcm_s16le 3.00s |
| ✅ | audio | ogg→flac | 0.05 | flac 3.00s |
| ✅ | audio | ogg→opus | 0.11 | opus 3.01s |
| ✅ | audio | ogg→aiff | 0.02 | pcm_s16be 3.00s |
| ✅ | audio | ogg→wma | 0.04 | wmav2 3.00s |
| ✅ | audio | opus→mp3 | 0.2 | mp3 3.02s |
| ✅ | audio | opus→m4a | 0.25 | aac 3.00s |
| ✅ | audio | opus→wav | 0.04 | pcm_s16le 3.00s |
| ✅ | audio | opus→flac | 0.07 | flac 3.00s |
| ✅ | audio | opus→ogg | 0.16 | vorbis 3.00s |
| ✅ | audio | opus→aiff | 0.04 | pcm_s16be 3.00s |
| ✅ | audio | opus→wma | 0.06 | wmav2 3.00s |
| ✅ | audio | aiff→mp3 | 0.16 | mp3 3.03s |
| ✅ | audio | aiff→m4a | 0.26 | aac 3.00s |
| ✅ | audio | aiff→wav | 0.02 | pcm_s16le 3.00s |
| ✅ | audio | aiff→flac | 0.04 | flac 3.00s |
| ✅ | audio | aiff→ogg | 0.12 | vorbis 3.00s |
| ✅ | audio | aiff→opus | 0.08 | opus 3.01s |
| ✅ | audio | aiff→wma | 0.04 | wmav2 3.00s |
| ✅ | audio | wma→mp3 | 0.15 | mp3 3.00s |
| ✅ | audio | wma→m4a | 0.66 | aac 3.00s |
| ✅ | audio | wma→wav | 0.02 | pcm_s16le 2.97s |
| ✅ | audio | wma→flac | 0.04 | flac 2.97s |
| ✅ | audio | wma→ogg | 0.11 | vorbis 2.98s |
| ✅ | audio | wma→opus | 0.09 | opus 3.07s |
| ✅ | audio | wma→aiff | 0.02 | pcm_s16be 2.97s |
| ✅ | video | mp4→webm | 1.91 | vp9 3.03s |
| ✅ | video | mp4→avi | 0.23 | mpeg4 3.06s |
| ✅ | video | mp4→wmv | 0.19 | wmv2 3.09s |
| ✅ | video | mp4→gif | 0.46 | gif 3.00s |
| ✅ | video | mp4→mp3 | 0.09 | mp3 3.06s |
| ✅ | video | mov→webm | 2.06 | vp9 3.03s |
| ✅ | video | mov→avi | 0.21 | mpeg4 3.06s |
| ✅ | video | mov→wmv | 0.2 | wmv2 3.09s |
| ✅ | video | mov→gif | 0.51 | gif 3.00s |
| ✅ | video | mov→mp3 | 0.09 | mp3 3.06s |
| ✅ | video | mkv→webm | 2.1 | vp9 3.05s |
| ✅ | video | mkv→avi | 0.22 | mpeg4 3.08s |
| ✅ | video | mkv→wmv | 0.23 | wmv2 3.12s |
| ✅ | video | mkv→gif | 0.5 | gif 3.00s |
| ✅ | video | mkv→mp3 | 0.09 | mp3 3.08s |
| ✅ | video | webm→avi | 0.21 | mpeg4 3.03s |
| ✅ | video | webm→wmv | 0.18 | wmv2 3.07s |
| ✅ | video | webm→gif | 0.44 | gif 3.00s |
| ✅ | video | webm→mp3 | 0.11 | mp3 3.02s |
| ✅ | video | avi→webm | 2.46 | vp9 3.04s |
| ✅ | video | avi→wmv | 0.14 | wmv2 3.12s |
| ✅ | video | avi→gif | 0.7 | gif 3.00s |
| ✅ | video | avi→mp3 | 0.09 | mp3 3.06s |
| ✅ | video | wmv→webm | 2.16 | vp9 3.07s |
| ✅ | video | wmv→avi | 0.17 | mpeg4 3.08s |
| ✅ | video | wmv→gif | 0.69 | gif 3.00s |
| ✅ | video | wmv→mp3 | 0.08 | mp3 3.00s |
| ✅ | video | gif→webm | 0.41 | vp9 2.00s |
| ✅ | video | gif→avi | 0.06 | mpeg4 2.00s |
| ✅ | video | gif→wmv | 0.05 | wmv2 2.00s |
| ✅ | image | png→webp | 0.07 | webp 0.00s |
| ✅ | tool | mute mp4 | 0.02 | audio removed |
| ✅ | tool | mute mov | 0.02 | audio removed |
| ✅ | tool | mute mkv | 0.02 | audio removed |
| ✅ | tool | metadata mp3 | 0.01 | title tag removed |
| ✅ | tool | metadata m4a | 0.02 | title tag removed |
| ✅ | tool | metadata wav | 0.06 | title tag removed |
| ✅ | tool | metadata flac | 0.02 | title tag removed |
| ✅ | tool | metadata mp4 | 0.02 | title tag removed |
| ✅ | tool | metadata mov | 0.02 | title tag removed |
| ✅ | tool | metadata mkv | 0.02 | title tag removed |
| ✅ | archive | create zip (with '--') | 0.0 | -dash.txt, a.txt, docs, docs/b.txt |
| ✅ | archive | create tar (with '--') | 0.0 | -dash.txt, a.txt, docs, docs/b.txt |
| ✅ | archive | create gz (with '--') | 0.0 | -dash.txt, a.txt, docs, docs/b.txt |
| ✅ | archive | zip→tar | 0.0 | 4 entries |
| ✅ | archive | zip→gz | 0.0 | 4 entries |
| ✅ | tool | extract zip | 0.0 | 4 entries |
| ✅ | archive | tar→zip | 0.0 | 4 entries |
| ✅ | archive | tar→gz | 0.0 | 4 entries |
| ✅ | tool | extract tar | 0.0 | 4 entries |
| ✅ | archive | gz→zip | 0.0 | 4 entries |
| ✅ | archive | gz→tar | 0.0 | 4 entries |
| ✅ | tool | extract gz | 0.0 | 4 entries |
| ✅ | archive | rar→zip | 0.0 | 5 entries |
| ✅ | archive | rar→tar | 0.0 | 5 entries |
| ✅ | archive | rar→gz | 0.0 | 5 entries |
| ✅ | tool | extract rar | 0.0 | 5 entries |
