# Installing Morph (friends alpha)

**Needs:** an Apple-silicon Mac (M1 or later) on macOS 13 Ventura or later.

Morph is ad-hoc signed and **not notarized** (no paid Apple Developer account yet). macOS will warn the first time
you open it. That's expected; the steps below are Apple's documented way to open software from outside the App Store.

## 1. Install

1. Open `Morph-<version>.dmg`.
2. Drag **Morph** onto **Applications**.
3. Eject the disk image.

Optional: check the download with `shasum -a 256 Morph-<version>.dmg` and compare it to the `.sha256` file.

## 2. Open it the first time

**macOS 15 Sequoia and later** (Apple removed the Control-click shortcut in macOS 15):

1. Double-click Morph in Applications. macOS says it can't verify the developer. Click **Done**.
2. Open **System Settings → Privacy & Security**.
3. Scroll down to the message about Morph and click **Open Anyway**, then confirm with your password.

**macOS 13 Ventura / 14 Sonoma:**

1. In Applications, **Control-click** (or right-click) Morph and choose **Open**.
2. Click **Open** in the dialog.

You only do this once. Morph then appears in the **menu bar** (no Dock icon) and shows a short “Try it once” practice.

## 3. Permissions you might see

- **“Morph wants to control Finder”**: only when you use the keyboard shortcut (⌃⌥Space) to read the files selected in Finder. Click OK. Dragging never needs this.
- **Folder access prompts** (Desktop, Documents, Downloads): macOS asks the first time Morph saves a converted copy into one of those folders.

Morph never needs Accessibility or Screen Recording permission, and it never connects to the internet to process files.

## 4. Quit / uninstall

- Quit: menu-bar icon → **Quit Morph**.
- Uninstall: quit, delete `/Applications/Morph.app`, and optionally `~/Library/Application Support/Morph` and
  `defaults delete app.morph.mac`.

## 5. Reporting a problem

Use the **Tester report** issue template in the GitHub repo. To include logs:

```bash
log show --last 10m --predicate 'process == "Morph"' > morph-log.txt
```
