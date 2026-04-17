# OpenPaste

A tiny open-source macOS menu bar app that cleans up clipboard text after you copy it out of terminals, AI coding tools, or styled chat windows. It rejoins wrapped lines, keeps paths and UUIDs intact, preserves lists and tables, and — optionally — flattens everything into a single line for pasting into Notes, Docs, or Slack.

Built because closed-source clipboard tools ask you to trust a binary with everything you ever copy. This one is small enough to read in one sitting.

## Trust posture

- **Open source**, MIT licensed.
- **No network calls.** No telemetry, no analytics, no auto-update. `grep -RE "URLSession|URLRequest|CFNetwork" Sources/` returns nothing.
- **Pasteboard is read, cleaned in-process, and written back.** That is the entire data flow. See [`ClipboardService.swift`](Sources/OpenPaste/ClipboardService.swift).
- **Accessibility permission** is only used to synthesize `Cmd+V` into the frontmost app after cleaning. The menu bar can still clean the clipboard without that permission; it just will not auto-paste.

## What it does

- Rejoins terminal-wrapped paragraph lines, including Korean text.
- Suppresses the stray space the formatter would insert at token boundaries: paths (`products/` + `coupang_partners`), UUIDs (`019d93da-` + `5d5a-...`), URL schemes (`https:` + `//...`), version numbers (`v1.` + `0.3`), and dashed identifiers (`error-` + `handling`).
- Drops shell line-continuation backslashes and rejoins with a single space.
- Strips terminal selection wrappers (shell prompts, `cat <<'EOF'` openers, `EOF` terminators, helper status lines).
- Preserves bullet and numbered lists, pipe tables, and fenced code blocks.
- Prefers `text/plain` over the noisy HTML payload that chat apps put on the pasteboard — no more styled chat bubbles landing in Notes.

## Two modes

| Mode | Hotkey | What it does |
| --- | --- | --- |
| Keep Structure | `⌃⌘P` | Rejoins wrapped lines, keeps paragraphs, lists, tables, and code blocks. |
| One Line | `⌃⇧⌘P` | Same cleanup, then flattens everything to a single line (strips list markers, collapses whitespace). Good for pasting into Notes, Google Docs, Slack. |

Both modes are also exposed as menu items with a "Clean Only" variant that rewrites the clipboard without simulating a paste keystroke.

The menu also has a **Show Raw Clipboard** window that shows the current `text/plain`, `text/html`, and both dry-run outputs side by side, for when something pastes wrong and you want to see what the formatter saw.

## Build from source

```bash
swift test
swift build -c release
./scripts/build-macos-app.sh
open dist/OpenPaste.app
```

The packaging script ad-hoc-signs the bundle with the stable identifier `io.local.openpaste` so macOS Accessibility permissions remain attached across rebuilds.

To install into `/Applications`:

```bash
rm -rf /Applications/OpenPaste.app
cp -R dist/OpenPaste.app /Applications/OpenPaste.app
codesign --force --deep --sign - --identifier io.local.openpaste /Applications/OpenPaste.app
open /Applications/OpenPaste.app
```

The app is ad-hoc signed only, so the first launch will show the standard "developer cannot be verified" Gatekeeper dialog. Right-click the app in Finder and choose **Open** the first time to bypass it.

## Project layout

```
Sources/OpenPaste/
  AppDelegate.swift         # menu bar, hotkeys, Show Raw Clipboard window
  ClipboardFormatter.swift  # core cleaner (shared by both modes)
  ClipboardService.swift    # NSPasteboard read/write, Accessibility, simulated paste
  GlobalHotKey.swift        # Carbon hotkey registration
  OpenPasteApp.swift        # SwiftUI entry point
Resources/
  Info.plist                # LSUIElement = YES (menu bar only)
scripts/
  build-macos-app.sh        # builds .app bundle into dist/
tests/OpenPasteTests/
  ClipboardFormatterTests.swift  # regression suite covering paragraph, list, table, block-preserve, and one-line cases
```

There is also a small browser prototype (`index.html`, `app.js`, `formatter.js`) from the earliest iteration, kept for reference.

## Tests

```bash
swift test
```

The suite covers every boundary case the cleaner is designed to handle: `/`, `_`, `-`, `.` + digit, `:` + `/`, `\\` line continuation, sentence boundaries, bullet and numbered list repair, pipe tables, Korean wrap, terminal prompt stripping, duplicate paragraph collapse, and one-line mode flattening.

## Contributions

PRs and issues welcome. Feature requests that would add network calls or telemetry will be declined — the whole point is that the binary does nothing behind your back.
