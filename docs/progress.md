# Build log

Newest first. Each entry matches a commit on `main`.

## 28 Oct: Teach Pilot by voice (2)
- "Pilot, when I say focus time, do open Notion, mute, full screen" makes a new phrase that runs that
  chain. Right after a miss, "Pilot, teach that: new tab" (or "that means new tab") maps the missed
  words to a command. "Pilot, forget focus time" removes it. Parsed before chain splitting, so the
  commas stay inside (matching rule 1b).
- Refuses, with a toast saying why: a phrase that already means something ("new tab already means
  New tab"), a command it doesn't understand right now, or "teach that" with no recent miss.
  Typo-tolerant app guesses don't count as taken: "focus time" otherwise reached Time Machine by
  prefix, and the taught phrase wins over that anyway.
- Stored in `commands/learned.json` (phrase → commands, the macro shape) and merged in on load;
  either file changing reloads both. commands.json's hand formatting is untouched. "What can I say?"
  lists taught phrases. Misses now end with 'Or say "teach that: …"'.
- Checked here through the app: teach, all three refusals, forget, forget-unknown. 106 BrainCheck cases.

## 28 Oct: Show numbers (1c)
- "Pilot, show numbers" (or "show labels", "show hints") puts a yellow numbered badge on every
  button, link, tab, row, field and menu-bar title in the front window, top to bottom, left to right.
  Then "Pilot, click 12" (or "number 12", "click twelve", "click number twenty-one") presses it.
  This is the fallback for icons with no name and for ties ("2 matches … Say show numbers").
- Badges clear after a click, on "hide numbers", when another app comes forward (the ⌃⌥P bar doesn't
  count), or after 20 s. One click-through panel per screen, above full-screen apps and all Spaces.
- With no badges up, a number is just a name, so "click 2" still finds a "2" link (Google's page 2).
- "show numbers" no longer opens the Numbers app; "close numbers" never quits it.
- Checked here: badges up + "click 99" → "No number 99 on screen", nothing pressed. Badge placement
  needs your eyes (test list in setup.md).
- 98 BrainCheck cases.

## 28 Oct: Fix "switch back" (never worked)
- Pilot listened for app switches on the wrong notification centre, so its app history stayed empty
  and "switch back" always said "No previous app yet". It's in the demo script at 1:25. Checked with
  a test program: the default centre got 0 activations, NSWorkspace's centre got 2.
- The same mistake means the backup frontmost-app paste tap (`Taps.swift`) never follows the front
  app. Left as is: every real Wispr paste so far came through the session tap.

## 28 Oct: Click by name (1b)
- "Pilot, click Sign in", "press Send", "tap Downloads", "choose English", "select …": Pilot walks the
  front window through Accessibility and presses the element with that name: exact name first, then
  names starting with it, then names containing all its words. Window elements beat menu items,
  controls beat plain text. If two are equally good it refuses ("2 matches … Say show numbers").
  "click the send button" also tries "send". The toast names what it clicked.
- Pressing: AXPress where supported, otherwise a real click at the element's centre (rows, cells,
  text fields). Unnamed list rows and web buttons are named by the text inside them.
- Chrome and Electron apps are asked once to expose their page content (AXEnhancedUserInterface /
  AXManualAccessibility). Chrome answered "not implemented" but exposed the page anyway.
- Measured here (read-only walks): WhatsApp 87 nodes in 89 ms (30 of 31 buttons named), Chrome
  2,210 nodes / 288 elements in 186 ms. Caps: 3000 nodes, depth 40, 300 ms.
- Literal phrases still win: "press enter", "press the enter key", "select all", "press escape".
- Chrome has no side-panel shortcut, menu item or toolbar button, so that command stays TODO.
- 88 BrainCheck cases.

## 28 Oct: Menu items as commands (1a)
- When nothing in commands.json matches, Pilot reads the current app's menu bar through Accessibility
  and presses the item whose title matches exactly (same normalising as commands): "Pilot, duplicate
  tab", "Pilot, export as PDF", "Pilot, pin tab". Works mid-chain for running apps ("open chrome,
  duplicate tab"). Never fuzzy, never the Apple menu, only enabled items. Matching rule 8 in Brain.swift.
- Menus are read only on that miss path, breadth first with a 150 ms cap, then cached 30 s.
  Measured here: WhatsApp 60 items in 87 ms, Chrome 168 items in 121 ms. Pressing WhatsApp's
  "Chats" item end to end: 60 ms.
- The first read per app writes every title and shortcut to debug.log (`grep "menu WhatsApp"`).
  Verified from it: WhatsApp search really is Cmd+F (File › Search). Chrome has no side-panel menu
  item, so that command stays TODO.
- "What can I say?" lists the front app's menu items. Chrome's Tab and Window menus list open tabs by
  title, so saying a tab's exact title switches to it.
- Also fixed a real miss: "can you reduce the volume". 76 BrainCheck cases, all passing.
- Testing without your help: `open -n -g ~/Applications/Pilot.app --args --run "…" --app WhatsApp`
  runs one command with Pilot's own Accessibility permission (a terminal has none).

## 28 Oct: Fix chains leaving the app, "show numbers", app display names
- "can you open music and search Florida" opened Music, then searched in Chrome. A chain that switches
  to an app now prefers commands that stay in that app; Apple Music got its own search (Cmd+F, Enter).
- "show numbers" opened the Numbers app: the phrase is now reserved and says it isn't built yet
  (it's one of the screen-control proposals).
- "can you open OBS Studio" missed: apps are now also known by their display names ("OBS Studio",
  "FL Studio", "PyCharm"), and apps one folder deep (DaVinci Resolve) are found.
- 63 BrainCheck cases, all passing.

## 28 Oct: Fix "search X in WhatsApp" opening Chrome
- Cause: "in WhatsApp" correctly switched context to WhatsApp, but with no WhatsApp search command
  the global web search (which always opens Chrome) was accepted.
- Fix in the Brain: a command aimed "in/on <app>" (or naming an app mid-sentence) must stay in that
  app; commands that would open a different app are skipped. Apps without their own search fall back
  to the standard Cmd+F find. Added a WhatsApp search command (Cmd+F, unverified shortcut).
- 5 new BrainCheck cases, including the exact sentence from the log.

## 28 Oct: Demo script
- `docs/demo.md`: a timed 2-minute script using only commands covered by BrainCheck.

## 28 Oct: First real Wispr test → matcher v2
- **Wispr interception confirmed working.** Every Wispr paste reached the *session* tap from
  `com.electron.wispr-flow.accessibility-mac-app`; "Pilot, open Chrome and search hello" was swallowed
  and ran. Accessibility survived a rebuild (stable signature works).
- Failures from the real log, all fixed and now in BrainCheck: "open a new Chrome tab" (app named
  mid-sentence), "can you switch the Chrome profile to Jaya Surya" (no profile support),
  "open Chrome in a new tab and search hello".
- Brain v2: app named anywhere in a command, "search X on youtube", sites, URLs, tab numbers
  ("tab three", "last tab"), runtime slot values (Chrome profiles), "Didn't catch … Try …"
  suggestions, more fillers ("can you", "I want to", "for me"). Matching 30 ms → ~1–2 ms.
- commands.json v2: 84 commands, 17 websites. New: Chrome profiles by name, open/search sites,
  "ask Claude …", media keys + volume, switch back to previous app, hide, zoom, copy/paste,
  find on page, page down, Mission Control, screenshot, lock screen, more Finder/VS Code/Chrome.
- Verified here: "can you open GitHub" → Chrome tab in 158 ms (match 1.4 ms). 53 brain checks pass.

## 28 Oct: Setup guide
- `docs/setup.md`: permissions, Wispr dictionary, command bar test, the three-app Wispr test and
  exactly what to report back. README rewritten.

## 28 Oct: Menu-bar app, Hands, both triggers
- `app/build.sh`: builds, runs BrainCheck, assembles `Pilot.app`, signs it with a fixed self-signed
  certificate ("Pilot Local Signing", own keychain) and installs to `~/Applications`. The signature
  requirement is `identifier dev.jsurya.pilot + certificate leaf`, so permissions survive rebuilds.
- Hands (`Hands.swift`): open/switch apps (waits until the app is in front), quit, shortcuts, typing
  (unicode events, works in Chrome's address bar), scroll (moves the pointer into the front window first).
- Trigger A (`Taps.swift`): session tap + frontmost-app tap catch Cmd+V sent by Wispr only, read the
  clipboard, swallow it if it's a Pilot command. Every Wispr paste is noted in `debug.log` with which
  tap saw it. Unmatched "Pilot …" text passes through untouched.
- Trigger B: Control+Option+P opens the command bar; dictated text runs by itself, typed text on Enter.
- HUD toast, "What can I say?" window, usage log (`~/Library/Application Support/Pilot/usage.jsonl`),
  today's count in the menu, Open at Login.
- Verified here: "open finder" from the terminal ran in 271 ms (match 1.9 ms). Not yet verified:
  anything needing Accessibility (keys, Wispr interception). That needs your test.

## 28 Oct: Brain + commands.json
- `commands/commands.json`: 44 commands (global, Chrome, Claude, VS Code, Finder), app aliases,
  synonyms, filler words, 2 macros. Claude shortcuts verified from Claude.app's own menu.
  One `TODO`: Chrome has no fixed sidebar shortcut.
- `app/Sources/PilotBrain/Brain.swift`: trigger stripping, chain splitting, exact command matching,
  fuzzy app names, per-app commands, "… in <app>", macros. Matching rules documented at the top
  (the web version must copy them).
- `app/Sources/BrainCheck`: 27 checks against the real JSON, including speed (~2.5 ms per chain,
  debug build). Run: `cd app && swift run BrainCheck`

## 28 Oct: Plan review
- `docs/plan-review.md`: risks, Wispr paste investigation, and the one change to a locked decision
  (Swift Package Manager instead of an Xcode project, because Xcode isn't installed).

## Next
- [ ] Your Wispr test (docs/setup.md) → fix whatever it shows
- [ ] Website playground (reuses commands.json; port the Brain's matching rules to JS)
