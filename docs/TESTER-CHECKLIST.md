# Friend tester checklist (M1)

From spec §8.4 / §12. Tick each box and note your **macOS version** and **Mac model** (Apple menu → About This Mac).

## Setup
- [ ] Installed from the DMG and opened via the steps in INSTALL.md
- [ ] Morph icon appears in the menu bar; the “Try it once” window appears on first launch
- [ ] Completed “Try it once” (drag sample → tap ⇧ → drop on JPG → `try-me.jpg` appears)

## 1. The three wheels open from Finder **and** the desktop
- [ ] Start dragging a photo in a Finder window, tap **⇧**, and the conversion wheel appears at the pointer
- [ ] Same from a file on the **desktop**
- [ ] While still dragging, tap **⌘** (tools) and then **⌃** (actions): the wheel switches in place
- [ ] Release the key and keep dragging: the wheel stays open
- [ ] Drop on the **centre** or outside the ring: nothing is created

## 2. Ten conversions (check that the new file appears beside the original and opens)
- [ ] HEIC → JPG  - [ ] PNG → WebP  - [ ] JPG → PDF  - [ ] SVG → PNG
- [ ] WAV → MP3  - [ ] M4A → FLAC  - [ ] MP3 → OGG
- [ ] MOV → MP4  - [ ] MP4 → GIF  - [ ] ZIP → TAR.GZ
- [ ] Convert the same file twice: the second copy is named “… 2.ext” and nothing is overwritten

## 3. Five tools
- [ ] Compress a photo (Compress window opens at the drop point; estimate shown; Return applies)
- [ ] Trim a video (handles, ← → frame step, I/O keys, Apply → “… Trimmed.mov”)
- [ ] Trim audio with “Trim silent ends automatically”
- [ ] Crop Image at 1:1
- [ ] Metadata → Remove All on a phone photo (location gone in Finder ▸ Get Info)
- [ ] Extract a ZIP (one-shot → “… Extracted” folder); Remove Audio on a video (one-shot)

## 4. Six actions (drag a **folder** or a mixed selection, tap ⌃)
- [ ] AirDrop  - [ ] Float (shelf on the right edge; drag an item out into Mail)  - [ ] Copy (paste in Finder)
- [ ] Move (choose a folder)  - [ ] Copy Path (paste into Notes)  - [ ] Terminal opens in the folder

## 5. Keyboard path
- [ ] Select files in Finder, press **⌃⌥Space**: the wheel opens; arrows move, Return applies, Esc cancels
- [ ] Finder ▸ right-click ▸ Services ▸ **Convert with Morph…** opens the wheel

## 6. VoiceOver smoke test (⌘F5)
- [ ] Opening the wheel announces how many choices there are
- [ ] Arrowing announces “Convert to PNG, 2 of 7” (or similar)
- [ ] Job finished is announced (“Saved … beside the original”)

## 7. Display settings (System Settings ▸ Accessibility ▸ Display)
- [ ] **Reduce Motion** on: wheel fades instead of popping
- [ ] **Increase Contrast** on: wheel petals get dark outlines and a solid background

## 8. Privacy
- [ ] While a big video converts, run `lsof -i -a -p $(pgrep -x Morph)` in Terminal and it prints nothing (smoke test)

## Report
Open an issue with the **Tester report** template: what you did, what you expected, what happened, screenshots if possible.
