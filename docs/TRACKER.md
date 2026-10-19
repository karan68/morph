# Morph — feature tracker

_Updated 19 Oct 2026 · Current release: **v0.1.0-m1** (M1 friends alpha) · Scope source: [spec §4.2](spec/README.md)_

Legend: ✅ done & verified on CI · 🧪 done, needs a real-Mac test by the tester · ⬜ not started

## Summary

| Area | Done | Left |
|---|---|---|
| Conversion paths (of 275) | **174** (M1) | 101 → 75 in M2, 26 in M3 |
| File tools (of 26) | **7** | 19 (M2) |
| File actions (of 6) | **6** | — |
| App shell, UX, accessibility, packaging | ✅ | tester sign-off |

---

## ✅ Done — M1

### Conversions — 174 paths, all proven real ([CONVERSION-PROOF.md](CONVERSION-PROOF.md): 174/174, rename fakes caught 174/174)
- [x] Images (57): JPG · PNG · WebP · HEIC · TIFF · AVIF · BMP → each other + PDF; SVG input
- [x] Audio (56): MP3 · M4A · WAV · FLAC · OGG · Opus · AIFF · WMA → each other
- [x] Video (48): MP4 · MOV · MKV · WebM · AVI · WMV ↔ each other, → GIF, → MP3; GIF → video
- [x] Subtitles (4): SRT ↔ VTT, → TXT
- [x] Archives (9): ZIP · TAR · GZIP ↔ each other; RAR → ZIP/TAR/GZIP
- [x] AVIF output hidden automatically where macOS can't write it (macOS 14/15); available on macOS 26

### Tools — 7, all proven on real-world files ([TOOL-PROOF.md](TOOL-PROOF.md): 62/62 results real, 59/59 fakes caught)
- [x] Compress (images, audio, video, PDF · preset / target size / percentage · resize · keep metadata)
- [x] Metadata (view grouped + search, Remove All)
- [x] Crop Image (aspect presets, drag area, exact output size; batch = centred crop)
- [x] Trim Video (filmstrip, handles, frame step, I/O keys, timecodes; lossless for MP4/MOV)
- [x] Trim Audio (waveform, handles, “Trim silent ends automatically”)
- [x] Remove Audio (one-shot)
- [x] Extract archive (one-shot → “… Extracted” folder)

### Actions — 6
- [x] AirDrop · Float shelf · Copy · Move · Copy Path · Terminal (iTerm2 if installed)

### App & UX (matches spec mockups)
- [x] Menu-bar app (no Dock icon): status, recent files, pause, settings, help — 🧪
- [x] Drag → tap ⇧ / ⌘ / ⌃ → radial wheel → drop; switch wheels mid-drag; tap-once default; hold-to-open option — 🧪 **(biggest open item: real Finder drag)**
- [x] Wheel states: idle, highlighted, multi-file, empty, 1–9 petals, high-contrast
- [x] Key hint while dragging (first 10 drags)
- [x] Progress HUDs: running, batch, done (Show in Finder), error (Details, Try again), cancel
- [x] Output naming beside original, “name 2.ext” collisions, race-free reservation, atomic writes
- [x] Settings: General, Shortcuts (re-bind keys, record hotkey), Output, Accessibility, Privacy, About
- [x] First-run “Try it once” practice — 🧪
- [x] Keyboard path: ⌃⌥Space for Finder selection + Finder ▸ Services ▸ “Convert with Morph…” — 🧪

### Accessibility
- [x] VoiceOver roles, labels, announcements (wheel, petals, HUDs, tool windows) — 🧪 needs a human pass
- [x] Full keyboard control (arrows, Return, Esc, modifier switching)
- [x] Reduce Motion · Increase Contrast · Reduce Transparency respected
- [x] Contrast ≥ 4.5:1 for all text tokens

### Privacy / local-only
- [x] No AI / LLM / ML models; no network code anywhere in the bundle (static check on every binary)
- [x] FFmpeg built `--disable-network`; tests run with the network blocked by the OS

### Build, test, distribution
- [x] Private repo, CI on macOS 15 + 26, OS probe on macOS 14
- [x] Unit tests (Linux on Tokyo VM + macOS) · golden matrix 217/217 (macOS 15), 224/224 (macOS 26)
- [x] Independent Linux proof of conversions (CI job + Tokyo VM)
- [x] Independent Linux proof of all 7 tools on real CC0 / public-domain files ([test-corpus/real](../test-corpus/real/SOURCES.md))
- [x] Bugs found by the real-file proof and fixed: Compress could write a bigger file (now declines); PDF Remove All left the original XMP author/title; MP3 Remove All kept cover art; Compress PNG/WebP dropped EXIF/GPS with “Keep” on; Compress “Smallest” upsampled low-rate audio; misleading error for unsafe archives
- [x] Tokyo VM engine harness 113/113 (same FFmpeg 7.1 sources + flags)
- [x] Ad-hoc signed `.app` + DMG + SHA-256, GitHub pre-release, LGPL sources published
- [x] Native UI snapshots on CI ([snapshots/](snapshots)) · INSTALL.md · tester checklist · issue template
- [x] Tester AASTHA381 added to the repo

---

## 🧪 Waiting on tester (M1 sign-off)
- [ ] Real Finder/desktop drag → wheel appears at pointer → drop works (spec risk R1)
- [ ] Tool windows open at the drop point, Return/Esc work
- [ ] Actions on folders / mixed selections
- [ ] ⌃⌥Space + Services menu
- [ ] VoiceOver smoke test, Reduce Motion, Increase Contrast
- [ ] First open via Gatekeeper “Open Anyway”
- [ ] macOS 13 Ventura (no CI runner exists for 13)

---

## ⬜ Left — M2 Beta (75 conversion paths + 19 tools)

### Conversions (75)
- [ ] PDF → JPG / PNG / TXT / MD (4) — 300 DPI pages; Vision OCR for scanned text
- [ ] Documents (50): DOCX · Markdown · RTF · RTFD · Text clipping · TXT · EPUB → each non-PAGES target incl. HTML, PDF, EPUB, JPG, PNG
- [ ] Spreadsheets (21): XLSX · XLS · ODS · CSV · TSV ↔ each other, → PDF

### Tools (19)
- [ ] Images: Edit Photo · Annotate Photo · Add Background · Redact Photo (Vision faces/text) · Create PDF · Create Collage
- [ ] Video: Crop Video · Change Speed · Join Videos · Video Snapshots · Split Video · Redact Video
- [ ] Audio: Normalize Volume · Audio Visualizer · Convert Channels · Bleep Audio
- [ ] PDF: Split PDF · Merge PDFs · Organize PDF

### Exit criteria
- [ ] All 26 tools · Accessibility Inspector audit clean · VoiceOver + keyboard scripts pass

## ⬜ Left — M3 Complete (26 conversion paths)
- [ ] PDF → DOCX / PPTX / XLSX / EPUB with OCR (4)
- [ ] PPT / PPTX → PDF / JPG / PNG (6)
- [ ] Every path into or out of **Apple Pages** (16) — open question R2: no public file spec
- [ ] Developer ID signing + notarization (needs the $99/yr Apple Developer Program — currently “no”)
- [ ] 275 / 275 matrix report, or each gap documented

## Open questions / risks
| # | Item | Status |
|---|---|---|
| R1 | Cross-app drag detection works on real Macs | Waiting on tester |
| R2 | Pages format (16 paths) | Open — M3 |
| R3 | PDF → DOCX/PPTX/XLSX layout fidelity | Open — M3 |
| R4 | PPT/PPTX rendering without Keynote/LibreOffice | Open — M3 |
| R5 | AVIF/HEIC output per macOS version | ✅ Answered: AVIF write only on macOS 26 (14.8/15.7 hide it) |
| R7 | Gatekeeper friction (not notarized) | Mitigated by INSTALL.md; notarization deferred |
