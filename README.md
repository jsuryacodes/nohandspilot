# No Hands Pilot

Control your Mac by voice through Wispr Flow. Wispr is the ears; Pilot is the hands.

Hold the Wispr key anywhere and say **"Pilot, open Chrome, new tab, search for Docker networking"**.
Pilot catches the text before it lands in the text box and runs it: no trackpad, no AI round-trip,
a few milliseconds of matching. Dictation that doesn't start with "Pilot" is never touched.

Built for No Hands: The Wispr Challenge by WeMakeDevs × Wispr Flow (Oct 2026). Not affiliated with Wispr.

Demo (2 min): https://youtu.be/gMNiggA7Vck
Full walkthrough (11 min): https://www.youtube.com/watch?v=svUKJ5K3ZRI

## How it works

- **Trigger A:** Wispr pastes dictated text with Cmd+V. Pilot watches for Cmd+V sent *by Wispr*,
  reads the text, and swallows the paste if it starts with "Pilot".
- **Trigger B:** Control+Option+P opens a command bar you can dictate or type into.
- **No hands (optional):** with the wake word on, Pilot listens on-device for its name only, then
  starts Wispr Flow. Wispr transcribes every command. Say "Pilot", wait for "🎙 Listening…" (Wispr's
  mic takes ~0.37 s to open), then the command. When you go quiet (the mic's loudness), Pilot stops
  Wispr and runs what Wispr wrote; if Wispr sends nothing, nothing runs. The only word Pilot acts on from its own speech recognizer is "Pilot". Every word after it comes from Wispr Flow. Nothing Apple's recognizer transcribes besides the name is ever run, typed, joined into a command or logged. "Pilot, dictate"
  starts Wispr for free text.
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

Live: https://nohandspilot.vercel.app. Try Pilot in the browser at `/try`: a Mac that runs commands through Pilot's
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
