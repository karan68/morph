# Evidence log (raw outputs captured while writing the spec, 18 Oct 2026)

Only command output observed in this session is recorded here. Nothing is paraphrased or reconstructed.

## Tokyo VM probe: `ssh sandbox-vm-tokyo` (read-only)

```text
instance-20260814-203540                 # hostname
GPU 0: NVIDIA L4 (UUID: GPU-64900b02-…)
Linux 6.8.0-1070-gcp x86_64
Ubuntu 22.04.5 LTS
4                                        # nproc
Mem:            15Gi       534Mi        11Gi ...
/dev/root        97G   81G   17G  84% /
NVIDIA L4, 23034 MiB
ffmpeg: missing
soffice: missing
pandoc: missing
vips: missing
tesseract: missing
docker: /usr/bin/docker
swift: missing
```

The `~/.ssh/config` comment for this host reads `# PoC Sandbox VM (Tokyo - asia-northeast1-a)`. The HostName contains `asia-northeast1-a`.

`ssh a100-tokyo`:

```text
Failed to initialize session: failed to dial: websocket: bad handshake (response status was "502 Bad Gateway")
```

## Local Mac

```text
ProductVersion: 26.7.1   BuildVersion: 25G241   arm64   Apple M5 Pro
xcode-select: error: tool 'xcodebuild' requires Xcode ... command line tools instance
Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)
```

Santa:

```text
$ santactl status
  Mode | Lockdown
$ swiftc -O imgio.swift -o imgio && ./imgio
/bin/bash: line 8: 54153 Killed: 9               ./imgio
$ santactl fileinfo /tmp/imgio
Code-signed            : Yes, but ad-hoc
Rule                   : None
Expected Decision      : Blocked (Unknown, Lockdown mode)
```

The same Swift code ran successfully through the interpreter (`swift imgio.swift`). It printed:

```text
WRITE: public.jpeg public.png com.compuserve.gif public.tiff public.jpeg-2000 com.apple.atx org.khronos.ktx org.khronos.ktx2 org.khronos.astc com.microsoft.dds public.heic public.heics public.avif com.microsoft.ico com.microsoft.bmp com.apple.icns com.adobe.photoshop-image com.adobe.pdf com.truevision.tga-image com.ilm.openexr-image public.pbm public.pvr
READ: (includes) org.webmproject.webp public.avif public.heic public.jpeg-xl ... (no SVG type)
```

CoreAudio, using `say -o src.aiff` as the source:

```text
OK   WAVE/LEI16 -> RIFF (little-endian) data, WAVE audio, Microsoft PCM, 16 bit
OK   flac/flac -> FLAC audio bitstream data
OK   m4af/aac -> ISO Media, Apple iTunes ALAC/AAC-LC (.M4A) Audio
OK   m4af/alac -> ISO Media, Apple iTunes ALAC/AAC-LC (.M4A) Audio
FAIL MPG3/.mp3: Error: ExtAudioFileSetProperty ('cfmt') failed ('fmt?')
OK   caff/opus -> CoreAudio Format audio file version 1
OK   AIFF/BEI16 -> IFF data, AIFF audio
afconvert -f Oggf -d opus@48000 -> Error: ExtAudioFileClose failed ('pck?')
afconvert -f Oggf -d vorb       -> Error: ExtAudioFileSetProperty ('cfmt') failed ('fmt?')
```

```text
textutil -convert fmt: txt, rtf, rtfd, html, doc, docx, odt, wordml, or webarchive
bsdtar 3.5.3 - libarchive 3.7.4 zlib/1.2.12 liblzma/5.4.3 bz2lib/1.0.8
```

## Capability matrix (computed in Node)

```text
inputs 45 total conversion paths 275 tools 26 actions 6
```

The full output is in `capability-matrix.json`.

## Prototype tests: `node test-prototype.mjs` (Playwright + Chrome)

Final run, after the last prototype change:

```text
PASS  HEIC → PNG via drag + Shift  — centre label=PNG
PASS  live region announces highlight  — Convert to PNG, 2 of 7
PASS  collision → 'kyoto-trip 2.png'
PASS  MOV → Trim via Command opens tool window  — centre=TRIM
PASS  tool output 'harbor Trimmed.mov'
PASS  TXT has no tools → empty state  — No editing tools for TXT.Tap ⇧ to convert or ⌃ for actions.
PASS  Control → FLOAT adds to shelf  — FLOAT
PASS  keyboard: Return opens wheel with focus on first item  — Convert to PAGES
PASS  keyboard: ArrowRight → PDF, Return converts  — Convert to PDF
PASS  keyboard: Control switches to actions; Esc returns focus to file  — Choose a file action / budget.xlsx
PASS  multi-select (2 JPG) shows multi-file tools  — compress,removeMetadata,cropImage,createPDF,createCollage
PASS  Create PDF combines into one file
PASS  drop on centre cancels (no new file)
PASS  2-petal wheel: ZIP → GZIP makes 'project.tar.gz'  — tar,gz / GZIP
PASS  no console / page errors
```
