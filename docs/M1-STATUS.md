# M1 status — Morph friends alpha

_Last updated: 19 Oct 2026. Scope: spec §4.2 **M1 Friends alpha**; decisions from the owner: no Apple Developer
Program (ad-hoc signing), closed source, macOS 13 minimum, no sandbox in the friends build, private repo._

## What's built

| Area | Status | Where |
|---|---|---|
| 174 M1 conversion paths (images 57, audio 56, video 48 incl. GIF, subtitles 4, archives 9) | ✅ implemented + verified | `Sources/Engines` |
| 7 M1 tools: Compress, Metadata, Crop Image, Trim Video, Trim Audio, Remove Audio (Mute), Extract | ✅ implemented + verified | `Sources/Engines`, `Sources/ToolWindows` |
| 6 actions: AirDrop, Float (shelf), Copy, Move, Copy Path, Terminal | ✅ implemented | `Sources/MorphApp/Actions.swift` |
| Drag → tap ⇧/⌘/⌃ → radial wheel → drop (configurable keys, tap-once default, hold-to-open option) | ✅ implemented — **needs a real-Mac test** (see below) | `Sources/DragKit` |
| Keyboard path: ⌃⌥Space (Finder selection) + Finder ▸ Services ▸ “Convert with Morph…” | ✅ implemented | `HotKey.swift`, `Info.plist` |
| Progress HUDs (running / batch / done / error with Details + Try again), reveal in Finder, Recent | ✅ | `HUDController.swift` |
| Menu-bar menu, Settings (General/Shortcuts/Output/Accessibility/Privacy/About), first-run “Try it once”, help | ✅ | `Sources/MorphApp` |
| Accessibility: VoiceOver roles/labels/announcements, keyboard control, Reduce Motion, Increase Contrast / Reduce Transparency style, adjustable trim handles | ✅ implemented — VoiceOver needs a human pass | all UI targets |
| Local-only: no network code; FFmpeg built `--disable-network`; SVG rendered with CSP `default-src 'none'` | ✅ verified statically + OS-enforced during tests | `scripts/check-no-network.sh` |
| Shareable `.app` in a DMG (ad-hoc signed, hardened runtime, signed inside-out) + SHA-256 | ✅ built by CI | `scripts/make-app-bundle.sh` |
| LGPL compliance (FFmpeg 7.1 LGPL, dynamic libs, sources + configure line published, About text) | ✅ CI fails on a non-LGPL build | `THIRD_PARTY_NOTICES.md` |
| Tokyo VM engine harness (same FFmpeg version/flags, shared recipes) | ✅ 113/113 | `engine-harness/` |

## How it's verified (all automated, no binary was ever run on the owner's Mac — Santa Lockdown)

| Check | Where it runs | Result |
|---|---|---|
| Core unit tests (matrix totals 275/26/6, M1 = 174, naming & collisions, allocator under 20 parallel reservations, job queue limit/cancel, subtitles, byte-level metadata stripping for JPEG/PNG/GIF/WebP, wheel hit-testing, recipes) | Tokyo VM (Swift 6.1 Linux container) **and** macOS CI | 23/23 ✅ |
| Engine tests (rotated JPEG → upright PNG, crop, metadata, SVG sizing, writable formats) | macOS CI | ✅ |
| **Golden matrix** — every available M1 conversion + every tool through the real engines, outputs validated (codec, dimensions, duration, cue count, archive entries, metadata removed), run with **network denied by the OS** (`sandbox-exec (deny network*)`, verified to block `curl` first) | macOS 15.7 runner | **217/217** ✅ (167/167 conversions; AVIF *output* is unavailable on macOS 15 and is hidden automatically) |
| Same golden matrix | macOS 26.6 runner | **224/224** ✅ (**174/174** conversions incl. AVIF output) |
| ImageIO capability probe (spec risk R5) | macOS 14.8 / 26.6 runners | 14.8: 167 paths (no AVIF output) · 26.6: 174 |
| Signed bundle self-test: app launches, `ffmpeg`/`ffprobe`/`bsdtar` load their bundled dylibs under hardened runtime | macOS CI | ✅ |
| Static no-network check over every Mach-O in the bundle | macOS CI | ✅ |
| Every bundled binary has `minos 13.0`; no Homebrew/absolute paths | macOS CI (deps job) | ✅ |
| Engine harness: 56 audio paths, all non-VideoToolbox video/GIF paths, WebP, Mute, AV metadata, archive create/convert/extract incl. the exact `bsdtar … --` argument shape and a RAR fixture | Tokyo VM (Docker, Ubuntu 22.04) | **113/113** ✅ (18 VideoToolbox paths are macOS-only → covered above) |
| Native UI snapshots (wheels in standard + high-contrast style, Compress, Crop, Settings, onboarding, HUDs, Float shelf, key hint) rendered from the real views | macOS CI → `docs/snapshots/`, release asset | ✅ for visual comparison with `docs/spec/mockups` |

## Needs your one tester (cannot be verified on CI)

1. **The cross-app drag** (spec risk R1, the M0 question): Finder/desktop drag → global mouse monitor + drag
   pasteboard → tap ⇧ → wheel at the pointer → drop on a petal. Implemented exactly as spec §7.1 proposes; CI has no
   way to perform a real Finder drag. Checklist §1 in `docs/TESTER-CHECKLIST.md`.
2. VoiceOver reading order and announcements on real hardware (checklist §6).
3. macOS 13 Ventura specifically (no GitHub runner exists for 13; 14.8, 15.7 and 26.6 were tested). PDF Compress needs 13.4+ (SDK-verified) and says so if older.
4. First-open Gatekeeper flow (ad-hoc signed, not notarized) — steps in `INSTALL.md`.

## Deviations from the spec (and why)

| Spec | Built | Reason |
|---|---|---|
| Mockup 10 note: “Lossless cut when the cut points land on keyframes. Otherwise only the edges are re-encoded.” | MP4/MOV: **lossless, frame-accurate** (AVFoundation passthrough edit list). MKV: lossless if the start is a keyframe, otherwise the selection is re-encoded. The window states the actual method per file. | Edge-only re-encode + concat of mixed H.264 streams isn't reliable; I wouldn't ship text that overstates what happens. |
| Mockup 01 shows a custom glass dropdown | Native `NSMenu` with the same items, recent thumbnails, header and privacy footer | Full keyboard + VoiceOver behaviour for free (spec §6 priority). Highlight colour is the system's. |
| Settings pages other than Shortcuts weren't designed | General / Output / Accessibility / Privacy / About contain only settings the spec mentions (+ “Open at login”, standard for menu-bar apps) | Not to invent features. |
| §7.3 “every test uses an App Sandbox build” | Tests run under an OS network-deny profile (`sandbox-exec`) instead; the friends build has no sandbox | Owner decision: no sandbox for the friends build. The guarantee (OS blocks network during tests) is kept. |
| Icons | Lucide icons (as in the mockups), pre-rendered to template PNGs | Matches the mockups; ISC licence. |

## Build & share

- Every push to `main`: CI builds, tests, packages and uploads `Morph-<ver>.dmg` + `.sha256` + reports as a build artifact.
- Tag `v*`: CI also publishes a **GitHub pre-release** with the DMG, checksum, golden-matrix report, self-test, UI
  snapshots and the third-party sources zip (LGPL).
- Local development on the owner's Mac: `scripts/typecheck.sh` type-checks every module with `swiftc` without
  executing anything (SwiftPM's manifest step is blocked by Santa).
- Tokyo VM: `engine-harness/run-on-vm.sh` (Docker) and core unit tests in `swift:6.1-jammy`.
