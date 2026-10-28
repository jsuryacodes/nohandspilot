# No Hands Pilot

Control your Mac by voice through Wispr Flow. Wispr is the ears; Pilot is the hands.

Hold the Wispr key anywhere and say **"Pilot, open Chrome, new tab, search for Docker networking"**.
Pilot catches the text before it lands in the text box and runs it: no trackpad, no AI round-trip,
a few milliseconds of matching. Dictation that doesn't start with "Pilot" is never touched.

Status: in development for No Hands: The Wispr Challenge (Oct 2026). See [docs/progress.md](docs/progress.md).

## How it works

- **Trigger A:** Wispr pastes dictated text with Cmd+V. Pilot watches for Cmd+V sent *by Wispr*,
  reads the text, and swallows the paste if it starts with "Pilot".
- **Trigger B:** Control+Option+P opens a command bar you can dictate or type into.
- **No hands (optional):** with listening on, say "Pilot" and the command ("Pilot scroll right across
  space"). Apple's on-device speech recognizer hears "Pilot", offline, and Pilot starts Wispr's
  hands-free mode through Wispr's own link in that moment; Wispr transcribes the command. Wispr's mic
  takes ~0.36 s to open (with its fn key too), so in one breath the first words come from Apple's
  transcript, joined to Wispr's text. "Pilot, dictate" starts Wispr for free text.
- **Brain** (`app/Sources/PilotBrain`): platform-neutral matching against
  [`commands/commands.json`](commands/commands.json): phrases with slots, synonyms, app aliases,
  per-app commands, macros, chains, and any menu item of the front app by its exact title.
  Fully offline, rule-based. Teach it new phrases by voice ("when I say focus time, do …"); they're
  saved to `commands/learned.json`.
- **Hands** (`app/Sources/Pilot`): macOS actions: open/switch apps, shortcuts, typing, scrolling,
  and screen control through Accessibility (`Screen.swift`).

## Build

Needs macOS 13+ and the Xcode Command Line Tools (full Xcode not required).

```
app/build.sh          # build, sign, install to ~/Applications, launch
cd app && swift run BrainCheck   # matching self-checks
```

Setup and permissions: [docs/setup.md](docs/setup.md).
