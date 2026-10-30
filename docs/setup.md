# Setup and the Wispr test

Takes about 10 minutes. Pilot is already built and installed at `~/Applications/Pilot.app`
(airplane icon in the menu bar).

## 1. Grant Accessibility (once)

1. macOS showed "Pilot would like to control this computer". Click **Open System Settings**.
   If you missed it: Pilot menu → **⚠︎ Grant Accessibility permission…**
2. Turn **Pilot** on under Privacy & Security → Accessibility.
3. Within ~2 seconds the Pilot menu should say **Listening for "Pilot, …" in Wispr**.
   If it still shows the warning, quit Pilot from its menu and reopen it from `~/Applications`.
   If it *still* doesn't, also add Pilot under Privacy & Security → **Input Monitoring**.

Rebuilding (`app/build.sh`) keeps this permission. You shouldn't need to grant it again.

## 1b. Let Pilot control Music (once, the first time you say "play … on Apple Music")

macOS asks **"Pilot" wants access to control "Music"**. Click **Allow**. Pilot uses it only to find
and play a song from your library. If you click Don't Allow, "play X" still works through Apple
Music's search; change it later in System Settings → Privacy & Security → Automation → Pilot → Music.

## 2. Wispr dictionary (once)

Wispr Flow → Dictionary → add **Pilot**, so it's never heard as "Pilate" or "pilot's".

## 3. Test the command bar (no Wispr needed)

1. Press **Control+Option+P**. A bar appears.
2. Type `open chrome, new tab, search for docker networking` and press Enter.
3. Expected: Chrome comes forward, opens a tab, searches. A toast at the bottom says
   "✓ Opened Google Chrome → New tab → Searching docker networking".
4. Open the bar again and **dictate** into it with Wispr: "open Finder". It should run by itself,
   without pressing Enter.

## 4. The Wispr test (the big unknown)

Do this in **three apps**: TextEdit (new document), Chrome (any web text box, e.g. google.com's
search box), and the Claude desktop message box. In each one, click into the text box, then:

| Say with Wispr | Expected |
|---|---|
| "Pilot, open Finder" | **No text appears.** Finder comes forward. Toast "✓ Opened Finder". |
| "This is a normal sentence." | Text types normally. No toast. |
| "Pilot programs are useful." | Text types normally **and** a toast says "Didn't catch: programs are useful". |

Then also try "Pilot, scroll down" on a long web page, and a chain:
"Pilot, open Chrome, new tab, search for Docker networking".

## 5. What to send me

1. For each of the three apps: did "Pilot, open Finder" leave text behind? Did Finder open?
2. Did scroll go the right way (down = further down the page)?
3. The output of this command (it only shows Pilot's notes about each paste, not what you said):

   ```
   grep -E "Cmd\+V|Ran|error" ~/Library/Application\ Support/Pilot/debug.log | tail -30
   ```

How to read it if you're curious:
- `Cmd+V seen (session tap) … [com.electron.wispr-flow…] → Pilot command, swallowed`: works
  exactly as hoped.
- Only `(frontmost-app tap)` lines: Wispr sends the paste straight to the app. Still works.
- **No `Cmd+V` lines at all** while dictating: Wispr inserted the text another way. Tell me which
  app; the command bar stays the fallback there.

## 6. Screen control and new commands (28 Oct)

Each row: say it with Wispr (or type it into the ⌃⌥P bar without "Pilot,"). Afterwards, paste me:

```
grep -E "Menus of|Ran |error" ~/Library/Application\ Support/Pilot/debug.log | tail -30
```

**Scrolling (fixed 28 Oct).** The pointer jumps to the middle of the window, then the page scrolls.

| Say | In | Expected |
|---|---|---|
| "Pilot, scroll down" / "Pilot, scroll up" | Chrome on LinkedIn | The feed moves about half a screen |
| "Pilot, scroll right" / "Pilot, scroll left" | a wide page or spreadsheet | It moves sideways |
| "Pilot, scroll right across space" | any full-screen app | The next full-screen app or desktop on the right slides in |
| "Pilot, scroll left across space" | same | The one on the left |
| "Pilot, scroll up across space" / "scroll down across space" | any | Mission Control / this app's windows |

**Menu items (any app, no setup).** If no command matches, Pilot presses the menu item with exactly
that title in the front app. "What can I say?" lists them.

| Say | In | Expected |
|---|---|---|
| "Pilot, duplicate tab" | Chrome | A copy of the tab opens. Toast "✓ Tab › Duplicate Tab" |
| "Pilot, pin tab" | Chrome | The tab is pinned |
| "Pilot, new group" | WhatsApp | The new-group panel opens |
| "Pilot, export as PDF" | Preview (any open PDF/image) | The export sheet opens |
| "Pilot, duplicate" | Chrome | Nothing pressed: "Didn't catch" (titles must match exactly) |

**Click by name.** Pilot presses the visible button, link, tab, list row or field with that name.

| Say | In | Expected |
|---|---|---|
| "Pilot, click Downloads" | Finder (sidebar visible) | Finder shows Downloads. Toast "✓ Clicked "Downloads"" |
| "Pilot, click" + a chat's name | WhatsApp | That chat opens |
| "Pilot, click Feel Good" | Music, Home ("Find Your Mood" on screen) | The Feel Good station opens or plays, like a mouse click |
| "Pilot, click" + a link's text | Chrome, any page | The link opens |
| "Pilot, press enter" | any text box | Enter is pressed (the old command still wins) |
| "Pilot, click sign in" | a page with two "Sign in" links | Badges 1 and 2 on just those two (top to bottom), toast "✓ 2 × "Sign in": say "click 1" or "click 2"". Then "Pilot, click 2" or "Pilot, click the last one" presses the second |

The first click in Chrome or an Electron app (Claude, VS Code) after it starts takes ~0.3 s longer.

**Show numbers.** For icons without a name. (When "click" finds several matches, it numbers just those.)

| Say | In | Expected |
|---|---|---|
| "Pilot, show numbers" | Chrome | Yellow numbered badges on the tabs, toolbar buttons, links and menu bar. Each badge sits on the top-left corner of its element |
| "Pilot, click" + a badge's number | same | That element is pressed, badges disappear |
| "Pilot, show numbers", wait 20 s | any | Badges disappear by themselves |
| "Pilot, show numbers", then "Pilot, hide numbers" | any | Badges disappear |
| ⌃⌥P, type `show numbers`, Enter; then ⌃⌥P, type `click 3`, Enter | Finder | Badge 3 is pressed (the bar doesn't clear the badges) |

If a badge sits somewhere other than on its element (shifted, or on the wrong monitor), tell me which
app and whether you use more than one display.

**Teach Pilot.** Taught phrases are saved in `commands/learned.json`.

| Say | Expected |
|---|---|
| "Pilot, open a fresh tab" (in Chrome) | "Didn't catch …" (the text also lands in the field, as before) |
| "Pilot, teach that: new tab" | "✓ Learned "open a fresh tab" → new tab" |
| "Pilot, open a fresh tab" | A new tab opens |
| "Pilot, when I say focus time, do open Finder, full screen" | "✓ Learned …"; then "Pilot, focus time" runs both |
| "Pilot, when I say new tab, do mute" | Refused: "new tab" already means New tab |
| "Pilot, forget focus time" | "✓ Forgot "focus time"" |

**Open anything by name.** Needs the word file, folder or document (or "in Finder").

| Say | Expected |
|---|---|
| "Pilot, open file resume" | Your most recently used file with "resume" in its name opens. Toast names it and its folder |
| "Pilot, open the nohandspilot folder" | That folder opens in Finder |
| "Pilot, show demo in Finder" | Finder opens with docs/demo.md selected |
| "Pilot, open downloads" (from Chrome) | Downloads opens in Finder |
| "Pilot, open bluetooth settings" | System Settings opens on Bluetooth |

**Selected text.** Select a word or sentence first (in Chrome, Notes, anywhere).

| Say | Expected |
|---|---|
| "Pilot, search this" | A Google search for the selected text opens in Chrome |
| "Pilot, define this" (one word selected) | The Dictionary app opens on that word |
| "Pilot, translate this" | Google Translate opens with the text |
| "Pilot, ask Claude about this" | Claude opens a new chat with the text and sends it |
| "Pilot, search this" with nothing selected | "Select some text first"; your clipboard is unchanged |

## 7. No hands: say "Pilot" (30 Oct)

With the wake word on, Pilot listens on-device for its name only, then starts Wispr Flow. Wispr
transcribes every command.

The rule: The only word Pilot acts on from its own speech recognizer is "Pilot". Every word after it comes from Wispr Flow. Nothing Apple's recognizer transcribes besides the name is ever run, typed, joined into a command or logged.

1. Turn it on once: Pilot menu → **Listen for "Pilot"**, or say/type "start listening". Allow the
   Microphone and Speech Recognition prompts. It stays off until you do.
2. Say **"Pilot"**, wait for the toast **🎙 Listening…** (Wispr's mic is on ~0.37 s after Pilot hears
   its name), then the command: "open Chrome, new tab, search for Docker networking". A beat at a comma
   is fine; a 1 s quiet ends it. Pilot stops Wispr and runs Wispr's text. Words you say before the toast
   aren't heard by Wispr, and Pilot never fills them in.
3. If Wispr sends nothing (you said nothing, or it heard nothing), nothing runs and the toast says
   "Didn't get that from Wispr. Say it again".
4. Play/pause: open a YouTube video in Chrome.
   | Say | Expected |
   |---|---|
   | "Pilot, pause the video" (playing) | It pauses. Toast "✓ Paused" |
   | "Pilot, pause" again | Nothing pressed. Toast "✓ Already paused" |
   | "Pilot, play" | It plays. Toast "✓ Playing" |
   | "Pilot, pause" with Spotify/Music playing and no video on screen | Spotify/Music pauses (media key) |
   Wispr pauses what's playing while it listens and resumes it when it stops; Pilot acts 0.7 s after it
   stops Wispr. If "pause" ever ends with the video playing, that delay is the knob (`Hands.media`).
5. "Pilot", then "dictate", then talk: Wispr types it into the focused box. Pilot stops Wispr after
   2 s of quiet (the mic's loudness).
6. "Pilot", then "stop listening" turns it off (the mic closes).
7. Terminal with Secure Keyboard Entry on: works too, through the clipboard (section 8).
8. Hold fn and say "Pilot, scroll down": it scrolls once, and the log says `with fn held`.

```
grep -E "Wake word|Ran |Cmd\+V" ~/Library/Application\ Support/Pilot/debug.log | tail -30
```

## 7b. Play a song in Apple Music (30 Oct)

| Say | Expected |
|---|---|
| "Pilot, play Florida on Apple Music" (in your library) | It plays. Toast "▶ Florida!!! (feat. Florence + the Machine) — Taylor Swift" |
| "Pilot, play Bohemian Rhapsody in Music" (not in your library) | Music searches Apple Music and plays the first song result. Toast "▶ Bohemian Rhapsody — Queen (Apple Music)" |
| "Pilot, play Florida" with Music in front | Same as the first row |
| "Pilot, search for Florida" in Music | Search only, nothing plays |
| "Pilot, play" / "Pilot, pause" | Unchanged: the player's own button, or the media key |

If no song comes up within ~3 s, or its play button can't be pressed, the results stay on screen and
the toast says so.

## 8. Terminal (30 Oct)

"Pilot, …" works in Terminal with **Secure Keyboard Entry** on or off (Terminal menu → Secure
Keyboard Entry). While it's on, macOS hides Wispr's ⌘V from every other app, so Wispr's text lands
at your prompt. Pilot then reads it from the clipboard (Wispr marks its text there; your own ⌘C
never is), deletes exactly those characters with Backspace, and runs the command. It never presses
Return, never wipes what you typed before, and never touches dictation that doesn't start with
"Pilot". With the wake word, Wispr's text is the command whatever it starts with. You'll see the text for about half a second. The same applies to a password field, and
the Pilot menu says "Secure input is on" while it is. VS Code's terminal works like any other app.

| Say with Wispr, in Terminal | Expected |
|---|---|
| "Pilot, open Chrome" | Chrome comes forward; the prompt is empty again |
| "Pilot, new tab" | A new Terminal tab or window |
| "ls minus la" | `Ls -la` is typed at the prompt, nothing else happens |
| Your own ⌘C / ⌘V of "Pilot, open Finder" | Pasted as text, nothing runs |

## Everyday use

- **Change commands:** Pilot menu → Edit commands.json (it's `commands/commands.json` in the repo).
  Changes apply on your next command; if the file has a mistake, the toast says so.
- Shortcuts marked `"TODO"` show "Not set up yet". Replace them with the real keys.
- **Rebuild after code changes:** `app/build.sh` (rebuilds, re-signs, reinstalls, relaunches).
- **Usage stats:** the menu shows today's count. Every command is in
  `~/Library/Application Support/Pilot/usage.jsonl` (time, text, matched, ok, matchMs, totalMs, source).
- **Start with your Mac:** Pilot menu → Open at Login.

## Before submitting

- Make the GitHub repo **public** (judges must open it without asking).
- Wispr usage card: Wispr app → Insights → Your usage.
