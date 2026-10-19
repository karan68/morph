# Third-party notices

Morph bundles the following components. Each one keeps its own license. The **exact license files** are copied
from the pinned source tarballs into `Morph.app/Contents/Resources/Licenses/` at build time, and the exact source
tarballs are published with every release (`Morph-<version>-third-party-sources.zip`).

| Component | Version | License | How it's used | Source |
|---|---|---|---|---|
| FFmpeg (ffmpeg, ffprobe, libav*) | 7.1 | **LGPL v2.1 or later** (built without `--enable-gpl` / `--enable-nonfree`) | Separate helper executables + dynamically linked libraries in `Contents/Helpers` and `Contents/Frameworks` | https://ffmpeg.org/releases/ffmpeg-7.1.tar.xz |
| LAME (libmp3lame) | 3.100 | LGPL | Dynamically linked by FFmpeg (MP3 encoding) | https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz |
| libopus | 1.5.2 | BSD-style (Xiph.Org) | Dynamically linked by FFmpeg | https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz |
| libogg / libvorbis | 1.3.5 / 1.3.7 | BSD-3-Clause (Xiph.Org) | Dynamically linked by FFmpeg | https://downloads.xiph.org/releases/ |
| libvpx | 1.15.0 | BSD-3-Clause | Dynamically linked by FFmpeg (VP9) | https://github.com/webmproject/libvpx |
| libwebp (+ libsharpyuv, libwebpmux) | 1.5.0 | BSD-3-Clause | Dynamically linked by FFmpeg (WebP) | https://storage.googleapis.com/downloads.webmproject.org/releases/webp/ |
| libarchive (bsdtar) | 3.7.7 | BSD-style (see its COPYING) | Helper executable `Contents/Helpers/bsdtar` | https://github.com/libarchive/libarchive |
| Lucide icons | — | ISC | Template icons rendered to PNG (`Contents/Resources/icons`) | https://lucide.dev |

## FFmpeg (LGPL v2.1) compliance

Following the checklist at https://ffmpeg.org/legal.html:

- FFmpeg is built **without** `--enable-gpl` and `--enable-nonfree`. CI fails the build if the binary reports anything but the LGPL.
- FFmpeg libraries are **dynamically linked** and keep their original names (e.g. `libavcodec.61.dylib`).
- The exact FFmpeg source tarball and the configure line (`Contents/Resources/FFmpeg/CONFIGURE.txt`) are published next to every DMG. No changes were made to the FFmpeg source.
- The About pane says: “This software uses libraries from the FFmpeg project under the LGPLv2.1.”
- Morph's own license terms do not restrict reverse engineering of these components.
- FFmpeg is a trademark of Fabrice Bellard, originator of the FFmpeg project.
