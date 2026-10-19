# Morph

Zero-click, offline file converter for macOS (Apple silicon, macOS 13+). Drag a file, tap **⇧** for conversions,
**⌘** for file tools, or **⌃** for file actions, then drop on a petal. Everything runs on your Mac.

- **Status & verification:** [docs/M1-STATUS.md](docs/M1-STATUS.md) — milestone **M1 friends alpha**
- **Install (testers):** [INSTALL.md](INSTALL.md) · **Checklist:** [docs/TESTER-CHECKLIST.md](docs/TESTER-CHECKLIST.md)
- **Spec, mockups, prototype:** [docs/spec/README.md](docs/spec/README.md) · native UI snapshots: [docs/snapshots](docs/snapshots)
- **Downloads:** GitHub Releases (DMG + SHA-256) or the latest `build-mac` workflow artifact

## Layout (spec §7.4)

```text
Sources/
├── MorphApp/      menu bar, settings, onboarding, HUDs, actions, Float shelf, hotkey, Services, --self-test
├── DragKit/       drag detection, modifier polling, wheel panel/view, geometry & hit-testing
├── Capabilities/  registry generated from Resources/capability-matrix.json (275 · 26 · 6)
├── Jobs/          job queue, naming rules, race-free name reservation, safe writes
├── Engines/       ImageIO/WebKit, AudioToolbox/AVFoundation, bundled LGPL FFmpeg, PDFKit, bsdtar, subtitles
├── ToolWindows/   Compress, Metadata, Crop Image, Trim Video, Trim Audio
├── A11y/          design tokens, VoiceOver announcements, display options, icons
└── MorphCLI/      morph-cli used by the golden matrix
engine-recipes/    FFmpeg command lines shared by the app and the Tokyo VM harness
engine-harness/    Docker harness for the Tokyo VM (same FFmpeg 7.1 sources + flags)
scripts/           build-deps (LGPL FFmpeg etc.), make-app-bundle, make-corpus, run-matrix, check-no-network, typecheck
```

## Develop

- Type-check without running anything (works under Santa Lockdown): `scripts/typecheck.sh`
- Regenerate data: `node scripts/gen-capabilities.js`, `node scripts/gen-recipes.js`
- Full build/test/package happens on CI (`.github/workflows/build-mac.yml`, macOS runners).
- Tokyo VM: `engine-harness/run-on-vm.sh` · core unit tests: `docker run --rm -v "$PWD":/src -w /src swift:6.1-jammy swift test --filter CoreTests`
