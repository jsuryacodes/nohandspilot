# Build log

Newest first. Each entry matches a commit on `main`.

## 28 Oct: Brain + commands.json
- `commands/commands.json`: 45 commands (global, Chrome, Claude, VS Code, Finder), app aliases,
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
- [ ] Hands + menu-bar app: open/switch apps, shortcuts, typing, scroll, HUD, usage log
- [ ] Trigger A: intercept Wispr's paste (session tap + frontmost-app tap, debug log)
- [ ] Trigger B: Control+Option+P command bar
- [ ] `docs/setup.md`: permissions + the Wispr test you need to run
