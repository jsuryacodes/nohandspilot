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
- **Brain** (`app/Sources/PilotBrain`): platform-neutral matching against
  [`commands/commands.json`](commands/commands.json): phrases with slots, synonyms, app aliases,
  per-app commands, macros, chains. Fully offline, rule-based.
- **Hands** (`app/Sources/Pilot`): macOS actions: open/switch apps, shortcuts, typing, scrolling.

## Build

Needs macOS 13+ and the Xcode Command Line Tools (full Xcode not required).

```
app/build.sh          # build, sign, install to ~/Applications, launch
cd app && swift run BrainCheck   # matching self-checks
```

Setup and permissions: [docs/setup.md](docs/setup.md).
