# Morph — friends alpha (M1)

## What's new in 0.1.1
Fixes found by testing every tool on real-world files (see `TOOL-PROOF.md`, 62/62 real, 59/59 fakes caught):
- **Compress never makes a file bigger.** If a file is already well compressed, Morph says so and writes nothing (an optimised PDF used to grow 3×).
- **Metadata → Remove All on PDFs** now also removes the hidden XMP block (original author, title, dates).
- **Metadata → Remove All on audio** now also removes embedded cover art.
- **Compress PNG/WebP with “Keep camera & date info”** now really keeps GPS and camera details.
- **Compress “Smallest” on low-quality audio** no longer upsamples (files were getting bigger).
- **PNG Compress “Balanced”** is now a maximum-effort lossless re-encode (same pixels, smaller file).
- **Extract**: archives with unsafe “../” paths get a clear message instead of “damaged”; nothing is written.

---


Zero-click offline file converter for Apple-silicon Macs (macOS 13+). Drag a file, tap ⇧ / ⌘ / ⌃, drop on a petal.

**Install:** download the DMG below and follow `READ ME FIRST.md` inside it (or INSTALL.md in the repo).
The app is ad-hoc signed and not notarized, so the first open needs **System Settings → Privacy & Security → Open Anyway** (macOS 15+)
or Control-click → Open (macOS 13–14).

**In this build (spec §4.2 M1):**
- 174 conversion paths: images, audio, video (incl. GIF), subtitles, archives (hidden automatically if this macOS can't write a format, e.g. AVIF on older systems)
- 7 tools: Compress, Metadata, Crop Image, Trim Video, Trim Audio, Remove Audio, Extract
- 6 actions: AirDrop, Float, Copy, Move, Copy Path, Terminal
- Progress HUDs, Settings, first-run practice, keyboard path (⌃⌥Space + Services), VoiceOver announcements

**Verification attached:** `golden-matrix-report.md` (every path run through the real engines on CI with network denied by the OS)
and `self-test.json` (signed bundle launches, all helpers load).

**LGPL:** FFmpeg 7.1 (LGPL v2.1) and all third-party sources + the exact FFmpeg configure line are in `Morph-*-third-party-sources.zip`.

**Test checklist:** docs/TESTER-CHECKLIST.md · report problems with the “Tester report” issue template.
