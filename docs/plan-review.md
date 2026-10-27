# Plan review

Reviewed 25–28 Oct 2026 against `docs/handoff.md` and the build brief. Ranked by impact.

## 1. Trigger A (catching "Pilot, …") is plausible, with one real unknown

**Evidence.** I inspected the native helper inside Wispr Flow 1.6.1264
(`Wispr Flow.app/Contents/Resources/swift-helper-app-dist`). Its strings and linked symbols show:

- Dictated text goes through `pasteText`: Wispr writes a **promised (delayed) clipboard item**
  (`DelayedClipboardProvider`, `NSPasteboardItemDataProvider`), performs a paste, then **restores your
  old clipboard** a moment later.
- It decides whether the paste worked by whether *any app asked for the clipboard data*
  ("Failed Timeout timer cancelled - paste succeeded (data was requested)").
- It links both `CGEventPost` and `CGEventPostToPid`.

**What this means for Pilot.**

- Your hypothesis holds up: intercept Wispr's Cmd+V, read the clipboard, swallow the paste if the
  text starts with "Pilot". Reading the clipboard also counts as "paste succeeded" for Wispr, so it
  won't show a failed-paste warning, and it still restores your clipboard afterwards.
- **Unknown:** `CGEventPostToPid` delivers a key event straight to one app and **skips normal
  (session-wide) event taps**. If Wispr pastes that way, a normal tap never sees the Cmd+V.
  Pilot therefore installs **two taps**: a session tap, plus a tap on whichever app is frontmost.
  Every Cmd+V either tap sees is written to a debug log with which tap saw it and which process
  sent it, so your first test answers the question.
- **Only Wispr's pastes are inspected.** Pilot checks the sending process of each Cmd+V. Your own
  Cmd+V presses are never read or blocked.
- **Change from the brief:** if the text starts with "Pilot" but the rest isn't a command
  ("Pilot programs in India are…"), Pilot **lets the paste through** and only shows "Didn't catch".
  Swallowing it would silently destroy real dictation; a misheard command landing as text is the
  cheaper failure.
- Remaining risk: if Wispr inserts some text by setting the field's value through Accessibility
  instead of pasting, nothing can be intercepted for that field. The debug log will show "no Cmd+V
  seen". The hotkey command bar (trigger B) is the fallback for those cases.

## 2. Locked decision I changed: no Xcode project (Xcode isn't installed)

This Mac has only the Command Line Tools, so `xcodebuild` doesn't exist and I couldn't build or
verify an Xcode project. Installing Xcode is a ~12 GB download in exam week.

What the decision is really for still holds:

- **Native Swift menu-bar app:** yes. Built with Swift Package Manager (`app/Package.swift`) and
  `app/build.sh`, which assembles a normal `Pilot.app`.
- **Permissions survive rebuilds:** yes, and this never depended on Xcode. macOS ties Accessibility
  permission to the app's code signature. Xcode's default "Sign to Run Locally" signature changes
  on every build, so permissions would *not* survive. `build.sh` instead signs with a fixed,
  self-signed local certificate (created once, in its own keychain), so the signature stays the same.
- If you install Xcode later, `open app/Package.swift` opens the project in Xcode for editing.

## 3. Judging: "a live link judges can open and use" (25%) needs the website

Judges can't run an unsigned Mac app from a link (Gatekeeper blocks self-signed apps without a
right-click → Open), so the website is what earns the "it works" score. Two consequences:

- The matching rules must be simple enough to re-implement in JavaScript identically. They're
  written down at the top of `app/Sources/PilotBrain/Brain.swift`; keep them in sync when the
  web version is built.
- Budget real time for the web playground after the Mac core works (by Thu 30 Oct at the latest).

## 4. Wispr will reshape what you say

- Wispr's formatting adds punctuation and capitals ("Pilot, open Chrome.") and may write "Pilot:" or
  "Hey Pilot,". The Brain strips all of that, plus filler words ("um", "please", "can you").
- **Add "Pilot" to Wispr's dictionary** so it isn't heard as "Pilate"/"pilot's".
- Wispr may split a long chain oddly or turn it into a list. Commas, "then" and "and then" all
  separate commands; a plain "and" only splits when both halves are real commands
  (so "search for salt and pepper" stays one search).

## 5. macOS gotchas the plan didn't mention

- **Scroll goes to the window under the mouse pointer**, not the focused window. Pilot moves the
  pointer into the front window before scrolling. (You aren't using the mouse anyway.)
- **Chains need waits.** After "open Chrome", keys sent immediately land in the old app. Pilot waits
  until the app is actually frontmost (up to 3 s) before the next step.
- **Command bar focus.** The bar takes focus while you type; Pilot hands focus back to the previous
  app before running anything, or "new tab" would go to Pilot itself.
- **Password fields** turn on Secure Input, which blocks event taps. Pilot can't fire while a
  password field is focused. That's expected.
- **Hotkey clashes.** ChatGPT and Claude both use Option+Space. Pilot uses **Control+Option+P**,
  changeable in `commands.json`.

## 6. Safety against false fires

- Command words are matched exactly; only app names are fuzzy.
- If any part of a chain isn't understood, **nothing runs**, so you never get half a chain.
- "Quit" only works with an app name ("quit Chrome"), never alone.
- Shortcuts I couldn't verify are marked `"TODO"` in the JSON and show "not set up yet" instead of
  pressing a guessed key.

## 7. Smaller improvements (later)

- You have AeroSpace installed (not running right now). If you use it, voice commands for its
  bindings ("workspace 2" → Option+2, "focus left" → Option+H) are a cheap, high-value addition,
  since those shortcuts come straight from your config.
- Submit early for the daily draws, but check whether submissions can be edited first. Make the
  repo public before submitting.
- The usage log records whether each command came from Wispr or the command bar. Quote the Wispr
  share in the submission; it supports the 30% Wispr criterion.
