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
| "Pilot, click" + a link's text | Chrome, any page | The link opens |
| "Pilot, press enter" | any text box | Enter is pressed (the old command still wins) |
| "Pilot, click search" | Chrome on a page with several search boxes | Either it clicks one, or "N matches … Say show numbers" |

The first click in Chrome or an Electron app (Claude, VS Code) after it starts takes ~0.3 s longer.

**Show numbers.** For icons without a name, or when "click" finds several matches.

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

## 7. No hands: say "Pilot" (28 Oct)

1. Turn it on once: Pilot menu → **Listen for "Pilot"**, or say/type "start listening". Allow the
   Microphone and Speech Recognition prompts.
2. Say **"Pilot"**, wait for the 🎙 toast (Wispr starts listening), then say the command. Pause, and
   it runs about a second later.
3. "Pilot" … "dictate" … then talk: Wispr types it into the focused box until you pause.
4. "Pilot" … "stop listening" turns it off (the mic closes).
5. With the cursor in a text field (WhatsApp, Chrome, Notes): "Pilot" … "scroll down" runs and types
   nothing; "Pilot" … "swipe right" (not a command) shows "Didn't catch" and types nothing. The same
   with Wispr's key held: "Pilot, swipe right" types nothing.
6. Terminal with **Terminal menu → Secure Keyboard Entry** ticked: "Pilot" shows a ⚠︎ toast and Wispr
   doesn't start (macOS hides every keystroke into Terminal from other apps then, Wispr's paste too).
   Untick it and Terminal works like any other app.

```
grep -E "Wake word|after the wake word|Ran |Cmd\+V" ~/Library/Application\ Support/Pilot/debug.log | tail -30
```

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
