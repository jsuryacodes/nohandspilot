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
- **No hands:** use Wispr Flow's own hands-free mode and say "Pilot, …" as usual. Pilot never opens
  your microphone. Wispr Flow is the only thing that listens.
- **Play / pause:** "Pilot, pause the video" presses the player's own button in the front window
  (YouTube, Netflix, Spotify, Music), so "pause" never starts anything; with no player on screen it
  presses the media key.
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

## Website

Live: _(link coming)_. Try Pilot in the browser at `/try`: a Mac that runs commands through Pilot's
Brain (ported to TypeScript, passing every BrainCheck case) and the real `commands/commands.json`.

```
cd web && npm i && npm run dev   # the site, at localhost:5173
npm test                         # the Brain's checks and the desktop's command → effect tests
npm run e2e                      # builds, then checks the first visit in a real browser
```

To refresh the usage numbers on the site, from the repo root (counts and timings only; what you said
never leaves the Mac):

```
node scripts/export-stats.mjs    # ~/Library/Application Support/Pilot/usage.jsonl → web/public/stats.json
```

Design notes: [web/DESIGN.md](web/DESIGN.md).
