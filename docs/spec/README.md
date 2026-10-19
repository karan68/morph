# Morph: product and engineering spec

> **Morph** is a zero-click, offline file converter for macOS. Start dragging a file, tap **⇧** for format conversions, **⌘** for file-specific tools or **⌃** for file actions, and a radial wheel appears at the pointer. Drop on a petal and a new file is saved beside the original. Everything runs on the Mac; nothing is uploaded.

| | |
|---|---|
| **Codename** | Morph. Internal only; run a trademark and App Store name check before any public release. |
| **Doc date** | 18 Oct 2026 · updated 19 Oct 2026 |
| **Status** | M1 built and released (v0.1.1) — see [`../M1-STATUS.md`](../M1-STATUS.md) and [`../TRACKER.md`](../TRACKER.md) |
| **Deliverables** | This spec · [`morph-spec.html`](morph-spec.html) (self-contained copy) · [14 mockups](mockups/) · [clickable prototype](prototype/index.html) · [6 diagrams](diagrams/) · [capability matrix JSON](reference/capability-matrix.json) · [raw evidence log](reference/evidence-log.md) |

**Evidence tags used throughout.** Every claim carries one of these:

| Tag | Meaning |
|---|---|
| ✅ **Verified** | Stated by official documentation, or reproduced by our own tests and commands |
| 💭 **Inferred** | Reasoned from evidence; plausible but not confirmed |
| 🟣 **Morph** | Our design decision or proposal |
| ❓ **Unknown** | Not yet known. Must not be assumed; listed in [§10](#10-risks-unknowns-and-open-questions) |

---

## Contents

1. [TL;DR](#1-tldr)
2. [Product overview](#2-product-overview)
3. [Capabilities](#3-capabilities)
4. [Morph product spec](#4-morph-product-spec)
5. [Look and feel: mockups, prototype, motion](#5-look-and-feel)
6. [Accessibility spec](#6-accessibility-spec)
7. [Architecture: local-only, native macOS](#7-architecture)
8. [Running on a Mac and sharing with friends](#8-running-on-a-mac-and-sharing-with-friends)
9. [Tokyo VM plan](#9-tokyo-vm-plan-sandbox-vm-tokyo)
10. [Risks, unknowns and open questions](#10-risks-unknowns-and-open-questions)
11. [Decisions needed](#11-decisions-needed)
12. [Roadmap and test strategy](#12-roadmap-and-test-strategy)
13. [Appendix](#13-appendix)

---

## 1. TL;DR

- **What Morph is 🟣:** a menu-bar Mac app (no Dock icon). Drag a file, tap **⇧** for format conversions, **⌘** for file-specific tools, or **⌃** for file actions. A radial wheel appears at the pointer, you drop onto a petal, and a new file is saved beside the original. Everything runs locally. Apple-silicon Macs, macOS 13+.
- **Scale 🟣:** the full plan is **275 conversion paths across 45 input formats, 26 tools, and 6 actions** ([§3](#3-capabilities)). Milestone M1 delivers **174 conversions, 7 tools and all 6 actions**, each proven by automated tests.
- **How it's built 🟣:** a native Swift (AppKit + SwiftUI) menu-bar app with strong keyboard and VoiceOver support, and no network use at all.
- **Sharing with friends ✅:** GitHub's Apple-silicon macOS runners build an ad-hoc-signed `.app` inside a DMG, published as a GitHub release.
  - **Ad-hoc signing (free):** on macOS 15+ each tester clicks **System Settings → Privacy & Security → Open Anyway** once (Apple-documented).
  - **Developer ID + notarization ($99/yr):** gives a clean double-click install.
- **Your Mac ✅:** a binary-authorization agent (Santa) runs in **Lockdown** mode, and a locally compiled test binary was killed on launch. So we **don't run Morph on your Mac and don't try to bypass Santa**. You write code there; CI builds and tests it; testers run it.
- **Tokyo VM ✅:** `sandbox-vm-tokyo` is Ubuntu 22.04 x86_64 (4 vCPU, 15 GiB, NVIDIA L4, Docker). Linux **cannot build or run a macOS app**; it hosts the engine test harness (same FFmpeg version and codec flags as the app, minus macOS-only VideoToolbox) and the core unit tests. `a100-tokyo` was unreachable (HTTP 502) when checked.

---

## 2. Product overview

### 2.1 Interaction model 🟣

1. Start dragging a file (or several) in Finder or on the desktop.
2. **Tap** a modifier: **⇧ Shift** = conversions, **⌘ Command** = file tools, **⌃ Control** = file actions. Keys are configurable in Settings.
3. Release the key and keep dragging: the wheel stays open until you drop or cancel. Tap another modifier to switch wheels in place.
4. Drop on a petal. Conversions and edits save a **new copy** beside the original. Tools that need settings open a tool window at the drop point first.
5. A small progress window shows each job; the result is selected in Finder.
6. Keyboard path: a global shortcut (default ⌃⌥Space) opens the wheel for the Finder selection; arrows move, Return applies, Esc cancels. Finder ▸ Services ▸ “Convert with Morph…” does the same.

### 2.2 Product facts 🟣

| | |
|---|---|
| Platform | Apple-silicon Mac, macOS 13 or later |
| Lives in | Menu bar (`LSUIElement`), no Dock icon |
| Progress | One small progress window per job, with cancel; results revealed in Finder |
| Distribution (alpha) | Ad-hoc-signed DMG via a private GitHub release |
| Privacy | No network use, no analytics, no accounts; files never leave the Mac |

---

## 3. Capabilities

### 3.1 Conversion matrix (275 paths · 45 inputs)

The machine-readable version is [`reference/capability-matrix.json`](reference/capability-matrix.json). The source format never appears as a target. Some formats are input-only (SVG, RAR, PPT, XLS, RTF, RTFD, text clippings); HTML is output-only.

| Family | Input | # | Converts to |
|---|---|---:|---|
| Images | JPG | 7 | PNG, WEBP, HEIC, TIFF, AVIF, BMP, PDF |
| Images | PNG | 7 | JPG, WEBP, HEIC, TIFF, AVIF, BMP, PDF |
| Images | WEBP | 7 | JPG, PNG, HEIC, TIFF, AVIF, BMP, PDF |
| Images | HEIC | 7 | JPG, PNG, WEBP, TIFF, AVIF, BMP, PDF |
| Images | TIFF | 7 | JPG, PNG, WEBP, HEIC, AVIF, BMP, PDF |
| Images | SVG | 8 | JPG, PNG, WEBP, HEIC, TIFF, AVIF, BMP, PDF |
| Images | AVIF | 7 | JPG, PNG, WEBP, HEIC, TIFF, BMP, PDF |
| Images | BMP | 7 | JPG, PNG, WEBP, HEIC, TIFF, AVIF, PDF |
| Audio | MP3 | 7 | M4A, WAV, FLAC, OGG, OPUS, AIFF, WMA |
| Audio | M4A | 7 | MP3, WAV, FLAC, OGG, OPUS, AIFF, WMA |
| Audio | WAV | 7 | MP3, M4A, FLAC, OGG, OPUS, AIFF, WMA |
| Audio | FLAC | 7 | MP3, M4A, WAV, OGG, OPUS, AIFF, WMA |
| Audio | OGG | 7 | MP3, M4A, WAV, FLAC, OPUS, AIFF, WMA |
| Audio | OPUS | 7 | MP3, M4A, WAV, FLAC, OGG, AIFF, WMA |
| Audio | AIFF | 7 | MP3, M4A, WAV, FLAC, OGG, OPUS, WMA |
| Audio | WMA | 7 | MP3, M4A, WAV, FLAC, OGG, OPUS, AIFF |
| Video | MP4 | 7 | MOV, MKV, WEBM, AVI, WMV, GIF, MP3 |
| Video | MOV | 7 | MP4, MKV, WEBM, AVI, WMV, GIF, MP3 |
| Video | MKV | 7 | MP4, MOV, WEBM, AVI, WMV, GIF, MP3 |
| Video | WEBM | 7 | MP4, MOV, MKV, AVI, WMV, GIF, MP3 |
| Video | AVI | 7 | MP4, MOV, MKV, WEBM, WMV, GIF, MP3 |
| Video | WMV | 7 | MP4, MOV, MKV, WEBM, AVI, GIF, MP3 |
| Video | GIF | 6 | MP4, MOV, MKV, WEBM, AVI, WMV |
| PDF | PDF | 9 | DOCX, PAGES, PPTX, XLSX, JPG, PNG, EPUB, TXT, MD |
| Slides | PPT | 3 | PDF, JPG, PNG |
| Slides | PPTX | 3 | PDF, JPG, PNG |
| Spreadsheets | XLSX | 4 | ODS, CSV, TSV, PDF |
| Spreadsheets | XLS | 5 | XLSX, ODS, CSV, TSV, PDF |
| Spreadsheets | ODS | 4 | XLSX, CSV, TSV, PDF |
| Spreadsheets | CSV | 4 | XLSX, ODS, TSV, PDF |
| Spreadsheets | TSV | 4 | XLSX, ODS, CSV, PDF |
| Documents | DOCX | 8 | PAGES, PDF, TXT, MD, HTML, EPUB, PNG, JPG |
| Documents | PAGES | 8 | DOCX, PDF, TXT, MD, HTML, EPUB, PNG, JPG |
| Documents | MD | 8 | DOCX, PAGES, PDF, TXT, HTML, EPUB, PNG, JPG |
| Documents | RTF | 9 | DOCX, PAGES, PDF, TXT, MD, HTML, EPUB, PNG, JPG |
| Documents | RTFD | 9 | DOCX, PAGES, PDF, TXT, MD, HTML, EPUB, PNG, JPG |
| Documents | Text clipping | 9 | DOCX, PAGES, PDF, TXT, MD, HTML, EPUB, PNG, JPG |
| Documents | TXT | 8 | DOCX, PAGES, PDF, MD, HTML, EPUB, JPG, PNG |
| Documents | EPUB | 6 | PDF, DOCX, PAGES, TXT, MD, HTML |
| Subtitles | SRT | 2 | VTT, TXT |
| Subtitles | VTT | 2 | SRT, TXT |
| Archives | ZIP | 2 | TAR, GZIP |
| Archives | TAR | 2 | ZIP, GZIP |
| Archives | GZIP | 2 | ZIP, TAR |
| Archives | RAR | 3 | ZIP, TAR, GZIP |
| **Total** | **45 inputs** | **275** | |

### 3.2 Tools (26) 🟣

“Opens a window” = the tool asks for settings first; the others run immediately (one-shot).

| # | Tool (wheel label) | Single file | Multi-file selection | Opens a window | Output name |
|---:|---|---|---|:---:|---|
| 1 | Compress (COMPRESS) | JPG, PNG, WEBP, HEIC, TIFF, MP3, M4A, WAV, FLAC, MP4, MOV, MKV, PDF | JPG, PNG, WEBP, HEIC, TIFF, MP3, M4A, WAV, FLAC, MP4, MOV, MKV, PDF | ✅ | Compressed · same ext (WAV→FLAC) |
| 2 | Metadata (METADATA) | JPG, PNG, WEBP, HEIC, TIFF, MP3, M4A, WAV, FLAC, MP4, MOV, MKV, GIF, PDF | JPG, PNG, WEBP, HEIC, TIFF, MP3, M4A, WAV, FLAC, MP4, MOV, MKV, GIF, PDF | ✅ | No Metadata |
| 3 | Edit Photo (EDIT) | JPG, PNG, WEBP, HEIC, TIFF | — | ✅ | Edited |
| 4 | Annotate Photo (ANNOTATE) | JPG, PNG, WEBP, HEIC, TIFF | — | ✅ | Annotated · .png |
| 5 | Add BG (ADD BG) | JPG, PNG, WEBP, HEIC, TIFF | — | ✅ | Background |
| 6 | Crop Image (CROP) | JPG, PNG, WEBP, HEIC, TIFF | JPG, PNG, WEBP, HEIC, TIFF | ✅ | Cropped |
| 7 | Normalize Volume (NORMALIZE) | MP3, M4A, WAV, FLAC | MP3, M4A, WAV, FLAC | ✅ | Normalized |
| 8 | Remove Audio (MUTE) | MP4, MOV, MKV | MP4, MOV, MKV | — | Muted |
| 9 | Trim Video (TRIM) | MP4, MOV, MKV | — | ✅ | Trimmed |
| 10 | Split PDF (SPLIT) | PDF | PDF | — | Pages · folder |
| 11 | Organize PDF (ORGANIZE) | PDF | — | ✅ | Organized · .pdf |
| 12 | Extract Archive (EXTRACT) | ZIP, TAR, GZIP, RAR | ZIP, TAR, GZIP, RAR | — | Extracted · folder |
| 13 | Create PDF (CREATE PDF) | — | JPG, PNG, WEBP, HEIC, TIFF, SVG *(multi-only)* | — | `<first> Images.pdf` |
| 14 | Merge PDFs (MERGE PDF) | — | PDF *(multi-only)* | ✅ | `<first> Merged.pdf` |
| 15 | Crop Video (CROP) | MP4, MOV, MKV | — | ✅ | Cropped |
| 16 | Change Video Speed (SPEED) | MP4, MOV, MKV | — | ✅ | Speed <n>x |
| 17 | Join Videos (JOIN) | — | MP4, MOV, MKV *(multi-only)* | ✅ | `<first> Joined.mp4` |
| 18 | Video Snapshots (SNAPSHOT) | MP4, MOV, MKV | — | ✅ | Snapshot · .png |
| 19 | Split Video (SPLIT) | MP4, MOV, MKV | — | ✅ | Clips · folder |
| 20 | Audio Visualizer (VISUALIZE) | MP3, M4A, WAV, FLAC | — | ✅ | Visualizer · .mp4 |
| 21 | Trim Audio (TRIM) | MP3, M4A, WAV, FLAC | — | ✅ | Trimmed |
| 22 | Convert Audio Channels (CHANNELS) | MP3, M4A, WAV, FLAC | — | ✅ | Mono / Stereo |
| 23 | Create Collage (COLLAGE) | — | JPG, PNG, WEBP, HEIC, TIFF, SVG *(multi-only)* | ✅ | `<first> Collage.png` |
| 24 | Redact Photo (REDACT) | JPG, PNG, WEBP, HEIC, TIFF | — | ✅ | Redacted |
| 25 | Redact Video (REDACT) | MP4, MOV, MKV | — | ✅ | Redacted |
| 26 | Bleep Audio (BLEEP) | MP3, M4A, WAV, FLAC | — | ✅ | Bleeped |

### 3.3 File actions (6) 🟣

They work with folders, mixed selections, and files that have no conversion tools.

| Action | What it does |
|---|---|
| AirDrop | Send to a nearby Apple device using the system AirDrop sheet. |
| Float | Park items on a small always-on-top tray, then drag them out later. |
| Copy | Put the items on the clipboard so you can paste them in Finder. |
| Move | Pick a folder and relocate the original items to it. |
| Copy Path | Put each item’s full path on the clipboard, one per line. |
| Terminal | Start a Terminal session in the item’s folder (or the folder itself); iTerm2 if installed. |

### 3.4 Tool window requirements 🟣

All tool windows share one pattern: a circular **close ×** at top-left, a **centered title**, a hairline divider, the content, another divider, and the **primary action bottom-right** (“Apply”, “Compress”, “Save Bleeped Copy”…). Return = primary action, Esc = cancel.

| Tool | Required controls |
|---|---|
| Compress | File name and original size; **Goal: Preset / Target size / Percentage**; **Preset: Balanced / Strong / Smallest**; **Image size** (“Keep original dimensions” or a maximum); “Keep camera & date info”; estimated result |
| Metadata | Search field, fields grouped by section, **Remove All**, and the note that Remove All also clears hidden camera/processing data |
| Normalize Volume | Waveform plus playback; target loudness (LUFS), loudness range (LU) and true-peak limit (dBTP) |
| Crop Image / Crop Video | Aspect presets **Free · 1:1 · 16:9 · 9:16 · 4:3 · 3:4**, draggable crop area, exact **W × H px**; video adds a scrubber |
| Change Video Speed | Preview; speed stops **0.25× · 0.5× · 1× · 1.5× · 2× · 4×**; audio pitch preserved |
| Create Collage | Layout (grid / row / column / featured), columns, canvas ratio, width, image fit, spacing & background, image order |
| Add Background | Colour / gradient / image background, padding, corners, shadow, ratio |
| Edit Photo | Light (exposure, contrast, highlights, shadows…), colour (temperature, tint, saturation…) and detail sliders with per-row reset |
| Trim Audio / Trim Video | Handles on a waveform or filmstrip, selected length, start/end timecodes, frame step; audio adds **“Trim silent ends automatically”** |
| Bleep Audio | Bleep ranges over the waveform; preview original vs bleeped |
| Redact Photo / Video | Style **Solid / Blur**, colour, on-device face/text detection (photo); per-redaction time ranges (video) |
| Others | Join Videos and Merge PDFs (reorderable lists); Organize PDF (page grid); Split Video (split points or equal parts); Video Snapshots (pick frames, export PNGs); Audio Visualizer (waveform or still, landscape/portrait/square); Audio Channels (mono/stereo, per-channel level) |

### 3.5 Local-only principles 🟣

- Every conversion, compression and edit runs on the Mac; results are saved beside the original; originals are never modified.
- No network code in the app; the bundled FFmpeg is built with `--disable-network`; CI verifies both (see [§7.3](#73-local-only-guarantees-)).
- ✅ Mac App Store apps must be sandboxed (App Review Guideline 2.4.5(i)). A future App Store build would use the App Sandbox with user-granted folder access stored as security-scoped bookmarks.

---

## 4. Morph product spec

### 4.1 Goals and non-goals 🟣

**Goals**
1. The same zero-click gesture (drag → tap → drop), with conversions, tools and actions.
2. 100 % on-device: no network calls for processing, no analytics in the friends build.
3. Originals are never modified. Output goes beside the original with predictable names.
4. Accessible by default: a full keyboard path, VoiceOver, Reduce Motion, Increase Contrast and Reduce Transparency, and a tap-once (not hold) default.
5. A shareable `.app` for friends' Apple-silicon Macs.

**Non-goals for v1**
- Mac App Store submission.
- Payments or trial limits.
- Cloud sync or any account.
- Intel Macs.
- Windows or Linux clients.

### 4.2 Scope by milestone 🟣

| Milestone | Conversions | Tools | Actions | Exit criteria |
|---|---|---|---|---|
| **M0 Spike** | JPG ↔ PNG only | — | — | Drag from Finder, tap ⇧, wheel appears at the cursor within ≤ 50 ms of the tap, drop works, on 2 friends' Macs |
| **M1 Friends alpha** | **174 paths:** Images 57, Audio 56, Video 48 (incl. GIF), Subtitles 4, Archives 9 | Compress, Metadata, Crop Image, Trim Video/Audio, Mute, Extract | All 6 | Every path passes golden tests; [§12](#12-roadmap-and-test-strategy) checklist |
| **M2 Beta** | **75 paths:** PDF → JPG/PNG/TXT/MD (4). Documents (50): inputs DOCX, MD, RTF, RTFD, text clipping, TXT, EPUB → every non-PAGES target, incl. HTML (HTML is **output-only**). Spreadsheets (21). | the other 19: Merge/Split/Organize PDF, Create PDF, Normalize, **Crop Video**, Speed, Snapshots, Split/Join Video, Collage, Add BG, Redact Photo/Video, Channels, Visualizer, Bleep, Edit Photo, Annotate Photo | — | All 26 tools (7 + 19); a11y audit passes |
| **M3 Complete** | **26 paths:** PDF → DOCX/PPTX/XLSX/EPUB with OCR (4); PPT/PPTX → PDF/JPG/PNG (6); every path into or out of **PAGES** (16, if feasible, see [§10](#10-risks-unknowns-and-open-questions)) | — | — | 174 + 75 + 26 = **275 / 275** paths, or each gap documented |

### 4.3 Behaviour rules

| Rule | Spec | Basis |
|---|---|---|
| Conversion name | `<base>.<ext>`. `gz` becomes `.tar.gz`. `.tar.gz`/`.tgz` are stripped as one extension. | ✅ golden matrix |
| Collision | `<base> 2.<ext>`, `<base> 3.<ext>`… | ✅ golden matrix |
| Tool name | `<base> <Suffix>.<ext>`, e.g. `harbor Trimmed.mov`; folders for Split/Extract/Split PDF | ✅ golden matrix |
| Combine tools | `Merged.pdf`, `Images.pdf`, `Joined.mp4`, `Collage.png` prefixed by the first file's base | 🟣 |
| Name reservation | Destination names are allocated by **one serialized allocator** (Swift `actor`), which immediately creates a zero-byte placeholder with `O_CREAT \| O_EXCL`. Two parallel jobs can never pick the same name. On cancel or failure the placeholder is removed. | 🟣 |
| Write safety | Render to a temp file in the same folder, then `rename` over **our own placeholder** only. Never overwrite anything else, never touch the original. | 🟣 |
| Concurrency | 2 jobs in parallel, FIFO, each cancellable from its HUD | 🟣 |
| Multi-select | Same format: conversions plus multi-file tools. Mixed: actions only. | ✅ golden matrix |
| Cancel | Drop on the center, outside the ring, Esc, or ending the drag elsewhere: nothing is written | ✅ golden matrix |
| Errors | Plain language, original untouched, "Details" shows the engine log, "Try again" | 🟣 |
| Reveal | Select the new file(s) in Finder (`NSWorkspace.activateFileViewerSelecting`) | API ✅ |

---

## 5. Look and feel

### 5.1 Flows

![User flow](diagrams/01-user-flow.png)

![Drag state machine](diagrams/02-drag-state-machine.png)

### 5.2 Mockups (original Morph design) 🟣

Every screen is 1440×900 and rendered from [`mockups/src/mockups.html`](mockups/src/mockups.html). Each has numbered callouts explaining the design decisions.

| # | Screen | |
|---|---|---|
| 01 | Menu bar home | ![](mockups/01-menubar.png) |
| 02 | Drag starts: key hint | ![](mockups/02-drag-hint.png) |
| 03 | **Conversion wheel (⇧)** | ![](mockups/03-wheel-convert.png) |
| 04 | **Tools wheel (⌘)** | ![](mockups/04-wheel-tools.png) |
| 05 | **Actions wheel (⌃)** | ![](mockups/05-wheel-actions.png) |
| 06 | Wheel states: idle, multi-file, empty, high contrast | ![](mockups/06-wheel-states.png) |
| 07 | Job progress HUDs: running, batch, done, error | ![](mockups/07-progress.png) |
| 08 | Results beside the original (naming rules) | ![](mockups/08-result-finder.png) |
| 09 | Tool window: Compress | ![](mockups/09-tool-compress.png) |
| 10 | Tool window: Trim Video | ![](mockups/10-tool-trim.png) |
| 11 | Float shelf | ![](mockups/11-float-shelf.png) |
| 12 | Settings → Shortcuts | ![](mockups/12-settings.png) |
| 13 | First run: "Try it once" | ![](mockups/13-onboarding.png) |
| 14 | Keyboard and VoiceOver | ![](mockups/14-keyboard-a11y.png) |

### 5.3 Clickable prototype 🟣

Open [`prototype/index.html`](prototype/index.html) in Chrome or Safari. It runs on the **real capability matrix**: drag a file and tap ⇧/⌘/⌃, or Tab to a file and press Return. It also supports ⌘-click multi-select, a working Float shelf, Move, Copy Path, a Compress tool window, progress HUDs, naming collisions, live-region announcements, and Reduce Motion, Increase Contrast and Hold-to-open toggles.

![Prototype](prototype/prototype-screenshot.png)

It's covered by 15 automated Playwright checks (all passing ✅; raw output in [evidence-log.md](reference/evidence-log.md), rerun via [§13.3](#132-regenerating-artifacts)): drag + Shift → PNG, collision naming, Command → Trim with a tool window, the empty state, Control → Float, keyboard open/arrow/apply, Esc focus return, multi-select tools, Create PDF combine, drop-on-center cancel, a 2-petal wheel (ZIP → `project.tar.gz`), and no console errors.

### 5.4 Design tokens 🟣

| Token | Value | Contrast (computed) |
|---|---|---|
| Accent | `#5b47f5` | white text on accent **5.73:1** |
| Accent ink / soft | `#3b2bc4` on `#ece9ff` | **7.59:1** |
| Ink / Ink-2 / Ink-3 on white | `#1c1b22` / `#4f4d5c` / `#6b6978` | **17.08 / 8.24 / 5.36 : 1** |
| Success (teal) | `#0c766c` | **5.5:1** on white, 4.9:1 on `#e3f6f3` |
| Danger | `#c62f2f` | **5.46:1** |
| Label on petal | `#1c1b22` on `#fbfbfe` | **16.54:1** |
| Type | SF Pro (system); SF Mono for timecodes | — |
| Radii | window 18 · panel 14 · control 8 · petal corner 12 | — |
| Wheel | outer r 160 pt, inner r 62 pt, gap 7 pt, ring backdrop r 168 pt; **0–9 petals** (0 = empty state; e.g. GIF tools = 1, SRT/ZIP = 2, RAR/PPT = 3, sheets = 4). Every count is rendered and hit-tested. | — |

### 5.5 Motion, sound and haptics 🟣

| Event | Default | With Reduce Motion |
|---|---|---|
| Wheel appears | 140 ms fade plus scale 0.9 → 1, ease-out | 100 ms fade only |
| Petal highlight | 80 ms fill; tick sound; trackpad haptic (`NSHapticFeedbackManager` ✅ API) | instant fill; sound and haptic unchanged |
| Switch wheel (⇧/⌘/⌃) | 120 ms crossfade of petals, ring stays put | instant |
| Drop | 120 ms petal flash, wheel fades 150 ms | 100 ms fade |
| HUD | slides 8 pt plus fade 180 ms; success auto-hides after 4 s | fade only |

Sound and haptics each have their own toggle. No information is conveyed by sound alone.

---

## 6. Accessibility spec

Target: the intent of WCAG 2.2 AA, applied to a native macOS app. Every row has a test.

| # | Requirement | Implementation (APIs ✅ verified in Apple docs) | Test |
|---|---|---|---|
| A1 | The wheel is a menu with labelled items | Petals are `NSAccessibilityElement` with role `menuItem` in a `menu`. Labels: "Convert to PNG", "Trim Video", "AirDrop". | Accessibility Inspector audit; VoiceOver reads "Convert to PNG, menu item 2 of 7" |
| A2 | State changes are spoken | `NSAccessibility.post(…, .announcementRequested, …)` on wheel open, highlight, job start, done and error | VoiceOver script |
| A3 | **Non-drag path** | Global shortcut (default ⌃⌥Space) opens the wheel for the Finder selection; plus a Finder **Quick Action / Services** entry "Convert with Morph…" | Use everything with the trackpad disabled |
| A4 | Full keyboard control | Arrows / Home / End move · Return applies · Esc cancels and restores focus · ⇧⌘⌃ switch wheels | Keyboard-only test plan |
| A5 | No simultaneous inputs required | **Tap once, wheel stays open** (default). Hold-to-open is optional. | Sticky Keys on: full flow works |
| A6 | Not colour alone | Highlight = fill **plus** center label **plus** focus ring | Grayscale screenshot review |
| A7 | Contrast ≥ 4.5:1 for text | Tokens in [§5.4](#54-design-tokens-) (all ≥ 4.9:1) | Contrast script in CI |
| A8 | Respect display preferences | `NSWorkspace.accessibilityDisplayShouldReduceMotion / …ReduceTransparency / …IncreaseContrast`; observe changes | Toggle each in System Settings while the app runs |
| A9 | Large targets | Smallest petal (9-petal wheel) ≈ 70 pt wide at mid-radius × 98 pt deep | Geometry unit test |
| A10 | Accessible tool windows | Standard controls; sliders and trim handles are adjustable with value strings ("Start, 3.1 seconds"); default and cancel buttons; Return / Esc | VoiceOver plus Full Keyboard Access per window |
| A11 | Understandable errors | Plain text, what happened, original untouched, next step | Copy review |
| A12 | Discoverability | First-run "Try it once" practice ([mockup 13](mockups/13-onboarding.png)) and a menu item for keyboard help | Friend usability test |

---

## 7. Architecture

### 7.1 Components

![Architecture](diagrams/03-architecture.png)

| Component | Responsibility | Key APIs |
|---|---|---|
| StatusItem + menu | Menu-bar presence, recent jobs, pause, settings | `NSStatusItem`, `LSUIElement` |
| **DragMonitor** | Detect that a file drag is in progress and read its URLs | `NSEvent.addGlobalMonitorForEvents` for **mouse** events ✅ (Apple: only **key** events need Accessibility trust); `NSPasteboard(name: .drag)` ✅ |
| **ModifierPoller** | Detect taps of ⇧/⌘/⌃ during a drag **without** the Accessibility permission | Poll `NSEvent.modifierFlags` ✅ (the "currently pressed modifier keys… independent of which events have been delivered") at 60 Hz while dragging |
| **WheelPanel** | Draw the wheel at the pointer; each petal is a drop target | `NSPanel` with `.nonactivatingPanel` ✅, floating level, `NSDraggingDestination` ✅ |
| CapabilityRegistry | Format → conversions / tools / actions (generated from the matrix JSON) | — |
| JobQueue | Async jobs, progress, cancellation | Swift concurrency |
| Engines | Do the work, on-device | see [§7.2](#72-engines-and-what-macos-can-do-natively) |
| OutputWriter | Naming, temp file + atomic move, reveal | `FileManager`, `NSWorkspace.activateFileViewerSelecting` ✅ |
| Actions | AirDrop, Float shelf, Copy, Move, Copy Path, Terminal | `NSSharingService(named: .sendViaAirDrop)` ✅, `NSPasteboard`, `NSOpenPanel`, `NSWorkspace` |

⚠️ The DragMonitor + ModifierPoller + panel-as-drop-target approach is our **proposal** 🟣. **M0 exists to prove it** on macOS 13–26 with Finder, the desktop, Mail and Safari as drag sources.

![Convert sequence](diagrams/04-convert-sequence.png)

### 7.2 Engines and what macOS can do natively

![Engine routing](diagrams/05-engine-routing.png)

Measured on this Mac (macOS 26.7.1) ✅:

| Capability | Result | Implication |
|---|---|---|
| ImageIO **write** | JPEG, PNG, HEIC, **AVIF**, TIFF, BMP, GIF, PDF (+ ICO, ICNS, PSD, TGA, EXR, JP2…) | Most image outputs are native. **AVIF write must be re-checked on macOS 13/14** ❓ |
| ImageIO **read** | includes **WebP**, AVIF, HEIC, JPEG-XL, RAW; **no SVG** | SVG needs resvg or WebKit |
| WebP **write** | not offered by ImageIO | bundle libwebp |
| `afconvert` encode | WAV ✅, AIFF ✅, FLAC ✅, AAC M4A ✅, ALAC M4A ✅, Opus-in-CAF ✅; **MP3 ✗** (`'fmt?'`), **Ogg Opus ✗** (`'pck?'`), **Ogg Vorbis ✗** | MP3/OGG/Opus/WMA need FFmpeg + LAME / libopus / libvorbis |
| `textutil` | txt, rtf, rtfd, html, doc, docx, odt, wordml, webarchive | Rich-text paths can be native |
| `bsdtar` | libarchive 3.7.4 | Bundle libarchive for a stable API |
| `NSAttributedString.DocumentType.officeOpenXML` | exists ✅ | DOCX via Foundation |

**Licensing (verified)** ✅
- **FFmpeg:** LGPL 2.1+ unless built with `--enable-gpl`. The official checklist says: no `--enable-gpl`/`--enable-nonfree`, dynamic linking, ship the matching source plus the configure line, and credit it in the About box.
- **Codecs and libraries:** LAME is LGPL. libwebp, libvpx and libvorbis are BSD-3-Clause; libopus is BSD-style. libarchive and cmark-gfm are BSD-style. resvg is Apache-2.0/MIT.
- 🟣 Use **VideoToolbox** for H.264/HEVC instead of the GPL x264/x265.
- GPL tools (pandoc, LibreOffice) may be used **only on the VM to generate test inputs**, never shipped.

### 7.3 Local-only guarantees 🟣

- **Enforce, don't sample.** Every test and CI run of the app uses an App Sandbox build **without** `com.apple.security.network.client` (and without `network.server`). With the sandbox on, macOS denies outbound connections no matter which library or subprocess tries.
- **Static check over every binary**, not just our Swift source: CI inspects the app and **all bundled dylibs** (`otool -L`, `nm -u`) and fails on networking frameworks or symbols (`Network`, `CFNetwork`, `NSURLSession`, `getaddrinfo`, `connect`…) outside an allowlist. FFmpeg is configured with `--disable-network`.
- No analytics, no crash upload. Logs stay local (`os_log`, subsystem `app.morph`).
- `lsof -i -a -p <pid>` in the friend checklist is a **smoke test only**. A point-in-time sample can miss short-lived connections, so the guarantee comes from the two checks above.
- **Future App Store build:** enable the App Sandbox **without** `com.apple.security.network.client`, so the OS itself blocks network access. Folder access for "save beside original" is granted once via `NSOpenPanel` and stored as a security-scoped bookmark 🟣.

### 7.4 Proposed repo layout 🟣

```text
morph/
├── Package.swift                # SwiftPM; app target + libraries
├── Sources/
│   ├── MorphApp/                # @main, status item, settings, onboarding
│   ├── DragKit/                 # DragMonitor, ModifierPoller, WheelPanel, geometry/hit-test
│   ├── Capabilities/            # registry generated from capability-matrix.json
│   ├── Jobs/                    # JobQueue, OutputWriter, naming rules
│   ├── Engines/                 # Image, AV, FFmpeg, PDF, Doc, Sheet, Archive, Subtitle
│   ├── ToolWindows/             # SwiftUI windows (Compress, Trim, Crop…)
│   └── A11y/                    # announcements, display-option observers
├── Vendor/ffmpeg/               # LGPL dylibs + exact source tarball + CONFIGURE.txt
├── Tests/                       # naming, matrix, geometry, engine smoke tests
├── engine-harness/              # Dockerfile, corpus generator, golden checks (Tokyo VM)
├── scripts/                     # make-app-bundle.sh, make-dmg.sh, check-no-network.sh
└── .github/workflows/build-mac.yml
```

---

## 8. Running on a Mac and sharing with friends

### 8.1 Constraints found on your Mac ✅

- `santactl status` reports **Mode: Lockdown**. A tiny Swift program compiled with `swiftc` (ad-hoc, linker-signed) was **killed with signal 9** on launch, and `santactl fileinfo` on it reports **"Expected Decision: Blocked (Unknown, Lockdown mode)"**. 💭 Any self-built, ad-hoc-signed Morph would most likely be blocked the same way unless IT adds an allowlist rule (e.g. for a signing certificate). Raw output is in [evidence-log.md](reference/evidence-log.md).
- Conclusion: **don't plan on running Morph locally**, and **don't work around Santa**. That would violate your organization's security policy. To run it yourself, request an allowlist exception from IT. Otherwise, test via CI and friends.
- Your Mac has Swift 6.4 Command Line Tools (no full Xcode), which is enough for editing and `swift build`. CI has full Xcode.

### 8.2 Build-and-share pipeline

![Build and share](diagrams/06-build-and-share.png)

GitHub-hosted **Apple-silicon (M1)** runners ✅: `macos-14`, `macos-15`, `macos-26` (= `macos-latest`), `xcode-27`. The workflow below is a **sketch 🟣, not yet run**:

```yaml
# .github/workflows/build-mac.yml (sketch)
name: build-mac
on: { push: { branches: [main] }, workflow_dispatch: {} }
jobs:
  build:
    runs-on: macos-15            # Apple silicon
    steps:
      - uses: actions/checkout@v4
      - run: swift build -c release
      - run: swift test
      - run: scripts/check-no-network.sh
      - run: scripts/make-app-bundle.sh .build/release/Morph dist/Morph.app   # Info.plist: LSUIElement, min macOS
      - name: Sign (ad-hoc; swap "-" for a Developer ID identity when available)
        run: codesign --force --options runtime --timestamp=none --sign - dist/Morph.app
      - run: hdiutil create -volname Morph -srcfolder dist/Morph.app -ov -format UDZO dist/Morph.dmg
      - run: shasum -a 256 dist/Morph.dmg > dist/Morph.dmg.sha256
      - uses: actions/upload-artifact@v4
        with: { name: Morph, path: "dist/Morph.dmg*" }
```

> Sign nested dylibs (FFmpeg etc.) first, inside out, before signing the app. ❓ Check current macOS-runner billing for private repos before relying on it.

### 8.3 Signing options

| | **Ad-hoc (free)** | **Developer ID + notarization ($99/yr ✅)** |
|---|---|---|
| What friends see | "Apple could not verify…" on first open | Opens normally |
| macOS 15 and later | ✅ Apple: Control-click "Open" no longer overrides Gatekeeper. Use **System Settings → Privacy & Security → Open Anyway**. | — |
| macOS 13–14 | Control-click the app → **Open** → **Open** | — |
| Effort | none | Apple Developer Program enrollment, certificate in CI secrets, `notarytool submit --wait`, `stapler staple` |
| Recommendation 🟣 | M0–M1 with 2–5 trusted friends | Before sharing more widely |

### 8.4 Friend test kit 🟣

- `Morph.dmg` plus `.sha256`, and a one-page **INSTALL.md** (drag to Applications, first-open steps per [§8.3](#83-signing-options), how to quit and uninstall).
- **Requirements:** Apple-silicon Mac, macOS 13+.
- **Sample pack:** synthetic files for every input format, generated on the VM ([§9](#9-tokyo-vm-plan-sandbox-vm-tokyo)).
- **Checklist:**
  1. Each wheel opens from Finder and the desktop.
  2. 10 conversions, 5 tools and 6 actions.
  3. Keyboard path (⌃⌥Space).
  4. VoiceOver smoke test.
  5. Reduce Motion and Increase Contrast.
  6. `lsof -i` shows no sockets.
- **Feedback:** a GitHub Issue template asking for macOS version, Mac model, steps, expected vs actual, and attached logs (`log show --last 10m --predicate 'subsystem == "app.morph"'`).
- **Live sessions:** a friend shares their screen while you watch the flow. No remote control of their Mac is required.

---

## 9. Tokyo VM plan (`sandbox-vm-tokyo`)

### 9.1 Verified state ✅

| | |
|---|---|
| Host | hostname `instance-20260814-203540`; zone `asia-northeast1-a` (from the SSH config comment and HostName); reached via `corp-ssh-helper`. Raw output: [evidence-log.md](reference/evidence-log.md) |
| OS / arch | Ubuntu 22.04.5 LTS, x86_64, kernel 6.8.0-1070-gcp |
| CPU / RAM | 4 vCPU / 15 GiB |
| GPU | NVIDIA L4 (23 GB). **Not needed for Morph.** Nothing in the app runs on a server GPU. |
| Disk | 97 GB, **84 % used, 17 GB free**. Prune Docker or add a disk before building images. |
| Tools | Docker ✅; ffmpeg, LibreOffice, pandoc, libvips, tesseract and Swift **not installed** |
| `a100-tokyo` | unreachable when checked (corp-ssh-helper 502); presumably stopped ❓ |

### 9.2 What it can and can't do

| Can (proposed 🟣) | Can't ✅ |
|---|---|
| 🟣 Run an **engine-harness** container with the **same FFmpeg version and codec flags** the app bundles (Linux build: no VideoToolbox), plus libwebp and libarchive. cmark-gfm and Apple-framework paths are tested on the macOS CI runner. | Build, sign or run a macOS `.app` (no macOS on GCP, and Apple frameworks don't exist on Linux) |
| 🟣 Generate **most** of the synthetic corpus: images, audio, video, subtitles, archives, CSV/TSV, Markdown/TXT, and (once LibreOffice/pandoc are installed in the container) DOCX/XLSX/ODS/PPTX/EPUB/XLS/PPT. GPL tools are fine here because nothing is shipped. **Not on Linux:** PAGES (needs Pages.app), RTFD and text clippings (macOS-only formats; create on a Mac with `textutil` or Finder) and HEIC. These are generated once on a macOS runner and committed as fixtures. | Test ImageIO, AVFoundation, VideoToolbox, PDFKit, Vision or `textutil` paths. Those run on the macOS CI runner. |
| Golden-file checks: `ffprobe` streams and durations, magic bytes, page counts, round-trip text diffs; post a report to the repo | Touch any real user file (never needed, never allowed) |
| Optional: self-hosted **Linux** GitHub runner for these jobs | — |

### 9.3 Setup steps (proposed, not yet executed)

```bash
ssh sandbox-vm-tokyo
df -h / && docker system df            # confirm space (17 GB free today)
git clone <morph repo> && cd morph/engine-harness
docker build -t morph-engine-harness .  # see Dockerfile sketch below
docker run --rm -v "$PWD/corpus:/corpus" -v "$PWD/out:/out" morph-engine-harness ./run-matrix.sh
```

```dockerfile
# engine-harness/Dockerfile (sketch). LGPL FFmpeg, same flags as the app minus VideoToolbox.
FROM ubuntu:22.04
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential nasm pkg-config git python3 \
    libmp3lame-dev libopus-dev libvorbis-dev libvpx-dev libwebp-dev libarchive-tools
ARG FFMPEG_TAG=n7.1
RUN git clone --depth 1 -b ${FFMPEG_TAG} https://git.ffmpeg.org/ffmpeg.git /src/ffmpeg && \
    cd /src/ffmpeg && ./configure --prefix=/opt/ffmpeg --enable-shared --disable-static \
      --disable-network --enable-libmp3lame --enable-libopus --enable-libvorbis --enable-libvpx --enable-libwebp && \
    make -j"$(nproc)" && make install
ENV PATH=/opt/ffmpeg/bin:$PATH LD_LIBRARY_PATH=/opt/ffmpeg/lib
COPY . /harness
WORKDIR /harness
```

> No `--enable-gpl` / `--enable-nonfree` means LGPL, per ffmpeg.org's checklist. `--disable-network` removes FFmpeg's network protocols. On macOS, VideoToolbox is **autodetected** (n7.1 `configure`: `--disable-videotoolbox … [autodetect]`), so the app build gets it without an extra flag ✅.

---

## 10. Risks, unknowns and open questions

| # | Item | Type | Impact | Plan |
|---|---|---|---|---|
| R1 | Cross-app drag detection on every Mac and drag source | ❓ | The core gesture | Built as §7.1 proposes; needs a real-Mac test by the tester (CI can't perform a Finder drag) |
| R2 | **PAGES** read/write (iWork format has no public spec) | ❓ | 16 conversion paths involve PAGES | Investigate Pages.app scripting (needs Pages installed + Automation consent) or drop from the plan |
| R3 | PDF → DOCX/PPTX/XLSX layout fidelity | ❓ | Quality risk | Layout may change when converting to editable formats. Start with text + tables + Vision OCR. |
| R4 | PPT/PPTX → PDF/images without Keynote or LibreOffice | ❓ | 6 paths | Evaluate options in M3; don't bundle LibreOffice (size) |
| R5 | AVIF/HEIC encode on macOS 13–14 | ❓ (✅ on 26.7) | Image outputs | Check on the `macos-14` runner and a friend's macOS 13 Mac, or raise the minimum OS |
| R6 | Ogg/Opus/MP3/WMA output | ✅ not native | Needs FFmpeg | LGPL FFmpeg plus codecs ([§7.2](#72-engines-and-what-macos-can-do-natively)) |
| R7 | Gatekeeper friction for friends | ✅ | Install drop-off | Clear INSTALL.md; Developer ID when ready |
| R8 | Your Mac can't run the build | ✅ | Slower dev loop | CI artifacts + friends; IT allowlist request |
| R11 | Trademark and name ("Morph") | ❓ | Public release | Search before release |

---

## 11. Decisions needed

1. **Apple Developer Program ($99/yr)?** Needed for clean installs (notarization). Recommend yes before more than 5 testers.
2. **Open-source or closed?** **Closed** (current plan): permissive components are fine (BSD, MIT, Apache-2.0, ISC: libwebp, libvpx, libvorbis, libopus, libarchive, cmark-gfm, resvg, Lucide), and **LGPL** works with obligations (FFmpeg, LAME: dynamic linking, ship sources and the configure line, credit). **GPL** components (x264/x265, pandoc, LibreOffice binaries) can't be shipped. **Open-source under the GPL** would allow them. A per-component license table (obligations, how each is linked) is an M1 deliverable.
3. **Minimum macOS:** 13 (wider reach) or 14 (simpler SwiftUI, fewer test targets). **Decided: 13.**
4. **Sandbox in the friends build?** Recommend **no** for M0–M2 (simpler) and **yes** for any App Store build.
5. **MVP scope:** confirm the M1 row in [§4.2](#42-scope-by-milestone-).
6. **GitHub repo:** private or public (affects runner minutes; check pricing first).

---

## 12. Roadmap and test strategy

| Phase | Build | Prove |
|---|---|---|
| **M0 Spike** | DragMonitor, ModifierPoller, WheelPanel, JPG↔PNG, CI build + ad-hoc DMG | Wheel ≤ 50 ms after tap; works on 2 friends' Macs (macOS 13/14 and 15+) |
| **M1 Alpha** | Images / audio / video / subtitles / archives; 7 tools; 6 actions; HUDs; settings; onboarding; VM harness + corpus | Golden tests green on VM + macOS CI; friend checklist; no sockets |
| **M2 Beta** | Remaining 19 tools (all 26), 75 PDF/document/spreadsheet paths (excluding PAGES), full a11y pass | Accessibility Inspector audit clean; VoiceOver and keyboard scripts pass |
| **M3 Complete** | OCR exports, slides, PAGES (or documented gap), Developer ID + notarization | 275-path matrix report |

**Test layers 🟣**
- **Unit (CI, macOS):** naming and collisions, capability registry vs JSON, wheel geometry and hit-testing, settings.
- **Engine conformance:**
  - VM: FFmpeg/libwebp/libarchive paths on the corpus.
  - macOS CI: Apple-framework paths on the same corpus.
  - Outputs are validated by probe and by content checks, not by byte equality.
- **UI (XCUITest):** tool windows, settings, keyboard path. The cross-app Finder drag is tested by friends (hard to automate).
- **Accessibility:** Inspector audit, scripted VoiceOver walkthrough, Full Keyboard Access, display-option toggles.
- **Privacy:** no-network source check, plus a runtime `lsof` check.
- **Performance budgets:** wheel appears ≤ 50 ms after the modifier tap (60 Hz poll ≈ 17 ms worst case); highlight ≤ 16 ms; job start ≤ 200 ms.

---

## 13. Appendix

### 13.1 Sources

- Apple, macOS Sequoia runtime protection: https://developer.apple.com/news/?id=saqachfa
- App Review Guidelines 2.4.5: https://developer.apple.com/app-store/review/guidelines/
- Apple Developer Program: https://developer.apple.com/programs/whats-included/
- GitHub-hosted runners: https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- FFmpeg legal: https://ffmpeg.org/legal.html · LAME license: https://lame.sourceforge.io/license.txt
- Apple API docs: `NSEvent.addGlobalMonitorForEvents`, `NSEvent.modifierFlags`, `NSPasteboard.Name.drag`, `NSDraggingDestination`, `NSWindow.StyleMask.nonactivatingPanel`, `NSWorkspace.accessibilityDisplayShouldReduceMotion` (+ transparency, contrast), `NSAccessibility.Notification.announcementRequested`, `NSHapticFeedbackManager`, `NSSharingService.Name.sendViaAirDrop`, `NSAttributedString.DocumentType.officeOpenXML`, `NSWorkspace.activateFileViewerSelecting`

### 13.2 Regenerating artifacts

```bash
# run inside the sibling ../build/ folder (scripts + node_modules live there; needs Google Chrome + Node)
./render-mockups.sh                 # 14 PNGs from mockups/src/mockups.html
node test-prototype.mjs             # 15 Playwright checks against prototype/index.html
mmdc -i diagrams/src/X.mmd -o diagrams/X.png -p puppeteer.json -c mermaid-config.json -s 2
node build-html.mjs                 # rebuilds morph-spec.html with embedded images
```
