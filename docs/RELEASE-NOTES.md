# Morph — friends alpha (M1)

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
