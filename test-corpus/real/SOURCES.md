# Real-world test corpus

Real files (not generated) used to prove Morph's tools and conversions on real content. Licences and authors were
read from each file's Wikimedia Commons page via the Commons API on 19 Oct 2026. Files are byte-identical to the
originals (size checked against the API, SHA-256 below).

| File | Source | Author | Licence | Size = source | SHA-256 |
|---|---|---|---|---|---|
| `jellyfish-panasonic-gps.jpg` | [Aurelia-aurita-3.jpg](https://commons.wikimedia.org/wiki/File:Aurelia-aurita-3.jpg) | MartinThoma | **CC0** | ✓ | `f4f54dc98dc4d9b364c41744f74c8a6d97b9d4f1fdde43d396bb40a48cb6a31f` |
| `armstrong-small-step.wav` | [Neil Armstrong small step.wav](https://commons.wikimedia.org/wiki/File:Neil_Armstrong_small_step.wav) | Neil Armstrong/NASA | **Public domain** | ✓ | `9c2146638c3acba0c05643d18ee3a03fd2d5c167f89cf160579f97266b368cd2` |
| `apollo8-merry-christmas.mp3` | [Apollo 8 - Merry Christmas.mp3](https://commons.wikimedia.org/wiki/File:Apollo_8_-_Merry_Christmas.mp3) | NASA | **Public domain** | ✓ | `a551004c3a02af8f1afb517d218485383306729cfc735f54296a5bb9dbb051cd` |
| `nasa-ksc-swearing-in.webm` | [KSC-04-S-00199 (ksc 061804 swornin).webm](https://commons.wikimedia.org/wiki/File:KSC-04-S-00199_(ksc_061804_swornin).webm) | NASA Kennedy Space Center | **Public domain** | ✓ | `cd1925082a514de9ccd7e3de90f094ae973c20bb326ee169035a437850ee0e59` |
| `nasa-plum-brook-factsheet-2008.pdf` | [Plum Brook Ordnance Works, Restoration Advisory Board- Quarterly fact sheet - USACE-p16021coll11-5946.pdf](https://commons.wikimedia.org/wiki/File:Plum_Brook_Ordnance_Works,_Restoration_Advisory_Board-_Quarterly_fact_sheet_-_USACE-p16021coll11-5946.pdf) | United States. Army. Corps of Engineers. Huntington District | **Public domain** | ✓ | `968e635c15643ab2063c7cec2bd42493edd63658f7c7d1ee1ca0493da01d3980` |
| `lame-3.100.tar.gz` | https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz | upstream project | **LGPL (software source archive)** | — | `ddfe36cab873794038ae2c1210557ad34857a4b6bdc515785d1da9e175b1da1e` |
| `libogg-1.3.5.zip` | https://downloads.xiph.org/releases/ogg/libogg-1.3.5.zip | upstream project | **BSD-3-Clause (software source archive)** | — | `fd4e5ba7e93b84b3ec41cdf01494cc586ef6e912b313dbab25512dd02665dfaf` |

Why these files:
- **jellyfish-panasonic-gps.jpg**: real Panasonic DMC-TZ41 photo with full camera EXIF **and GPS** (Metadata, Compress, Crop).
- **armstrong-small-step.wav**: real 1969 speech, 8-bit 11 kHz mono with natural pauses (Trim Audio, silence trimming, Compress WAV→FLAC).
- **apollo8-merry-christmas.mp3**: real MP3 with ID3 tags and **embedded cover art** (Metadata, Trim, Compress).
- **nasa-ksc-swearing-in.webm**: real NASA video **with speech audio** (VP9 + Opus) — source for MP4/MOV/MKV copies used by Trim Video, Remove Audio, Compress.
- **nasa-plum-brook-factsheet-2008.pdf**: real 4-page PDF from Acrobat Distiller with Title/Author/Creator metadata and full-page scanned images (Compress, Metadata).
- **lame-3.100.tar.gz / libogg-1.3.5.zip**: real software release archives with hundreds of files (Extract).

Derived inputs made at test time (content stays real, container changes) are listed in `scripts/make-real-corpus.sh`.
