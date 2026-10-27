# Build log

Newest first. Each entry matches a commit on `main`.

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
