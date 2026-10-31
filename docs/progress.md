# Build log

Newest first. Each entry matches a commit on `main`.

## 31 Oct: Demo video on the website
- The Demo section now plays the YouTube video (svUKJ5K3ZRI) in place of "on its way". It still loads
  YouTube only when you press play.

## 31 Oct: Wispr starts sooner after "Pilot", and "No Hands Pilot" stops it
- Your report: still woke on "No Hands Pilot", and the 0.6 s wait made Wispr start late. The wait is
  gone: Wispr starts the moment the recognizer writes "Pilot" (~0.3 s after you say it, plus Wispr's own
  ~0.37 s to open its mic, which Pilot can't shorten).
- Instead, the transcript runs one more second after the name, read only to check it: if "Pilot" turns
  out to sit next to "no" / "hands" (the recognizer writes "No…" as "Pilot", then corrects itself to
  "Pilot no hands pilot"), Pilot stops Wispr at once and drops its text, no toast. Nothing from that
  second is run, typed or logged.
- The recognizer's language model is now also taught "No Hands Pilot", "nohandspilot" and
  "nohandspilot dot vercel dot app", so it has the project's name to choose instead of "Pilot".
- What's left: on a false start, Wispr's bar can flash for a moment before it's stopped. Not tested here,
  at your request.

## 31 Oct: "No Hands Pilot" still woke Pilot: fixed at the cause
- Your report: it still woke. Recorded the recognizer's partial results on test audio (a throwaway
  probe signed as Pilot, never Pilot itself, transcript deleted after): saying "No…", it first writes
  "Pilot", then corrects itself to "Pilot no hands pilot". Pilot woke on that first lone "Pilot".
- Fix: the wake word now decides only once a word follows the name, or after 0.6 s of nothing (you
  waiting for Wispr), and checks two words on each side of the name for "no" / "hands" (and how the
  recognizer writes them: "hand", "hans", "hence", "and", "nohands"). And if a wake still slips
  through, Wispr's text starting with "No Hands Pilot" / "nohandspilot" is dropped quietly.
- Cost: "Pilot" + a pause now shows 🎙 Listening… ~0.6 s later; "Pilot open Chrome" in one breath is
  unchanged. Not re-tested here, at your request: you're testing it.

## 31 Oct: Saying "No Hands Pilot" doesn't wake Pilot
- Your ask. Wispr's text was already safe ("No Hands Pilot …" doesn't start with "Pilot"); the wake word
  wasn't: Apple's recognizer heard "pilot" inside the project's name and started Wispr (01:59:12 in the
  log: "Nohandspilot.vercel.app" then ran as a command). Now the wake word ignores "pilot" right after
  "hands"; "Pilot" on its own, anywhere else in a sentence, still wakes it.
- Tested live: "This is No Hands Pilot." and "The project is called No Hands Pilot.": no wake. Then
  "Pilot" … "volume up": woke and ran. (A first try, "I built No Hands Pilot …", woke on "I built",
  before the name was said: Apple heard "built" as the name. Worth knowing for the demo voiceover.)

## 31 Oct: "Pilot, remove the screenshot"
- Your ask: remove an uploaded screenshot by voice. The submission form's × on the thumbnail is a
  button named "Remove image 1" (read from the page, nothing pressed), so "click remove image" already
  pressed it. Added the phrases you'd say: "remove the screenshot", "delete the screenshot", "remove
  the (uploaded) image", as macros for "click remove image" (a macro wins over "delete {phrase}").
- Tested on a copy of the thumbnail in a local page, not your real form: "remove the screenshot" →
  `AXButton "Remove image 1"`, the image went (0.4 s). 3 BrainCheck and Vitest cases.

## 31 Oct: "Pilot, upload the screenshot"
- Your ask: in the demo, take a screenshot and upload it to the submission form by voice. "click Add
  images" already opened the file picker; picking the file was missing. Now "upload the screenshot"
  (also choose / attach / select / pick / add) with a picker open: ⌘⇧G, Pilot pastes the newest
  screenshot's full path, Return (the picker goes there and selects it), Return (Open), and checks the
  picker closed. It first checks a picker is really up (a "Cancel" button next to Open / Choose /
  Upload, waiting up to 3 s so it chains after the click), so ⌘⇧G is never sent to a page.
- Found while testing: a full-screen Retina screenshot is 10.7 MB, over the form's "up to 5 MB each".
  Over 5 MB, Pilot uploads a JPEG copy (80% quality, kept in Pilot's own folder) and the toast says
  so; your PNG isn't touched.
- Tested in Chrome on a local page with a file input: "click add images no file chosen, upload the
  screenshot" opened the picker and the page received "Screenshot 2026-10-31 at 1.43.28 AM.jpg"
  (1,640,454 bytes), 3.4 s in all. Earlier, without the JPEG step, the 10,743,320-byte PNG. Not tried
  on the real submission form. 3 BrainCheck and Vitest cases; demo.md has the step.

## 31 Oct: "Pilot, paste the screenshot"
- Your ask: paste a screenshot by voice, while plain "paste" keeps pasting the text or page link you
  copied. So the screenshot isn't put on the clipboard: "take a screenshot" saves it as before (⌘⇧3),
  and "paste the screenshot" (also "paste screenshot", "paste my last screenshot") takes your newest
  screenshot from the folder macOS saves them to, puts it on the clipboard just long enough to paste,
  then puts your clipboard back. Screenshots are told from other images by the tag macOS gives them
  (`kMDItemIsScreenCapture`). With the floating thumbnail on, macOS writes the file ~5 s after the
  shot; right after one Pilot took, it waits up to 8 s for it.
- New permission: the first time, macOS asks to let Pilot see your Desktop folder (you allowed it at
  01:18; the command waited on that prompt, 18 s).
- Tested live in TextEdit with "MY COPIED TEXT" copied: "paste the screenshot" put the image in (1.2 s),
  then "paste" put in "MY COPIED TEXT", and the clipboard still held it. 5 BrainCheck and Vitest cases.

## 31 Oct: "Pilot, paste" typed "Paste"
- Your report: saying "paste" typed the word instead of pasting. The log shows paste did run (⌘V in
  44 ms), but Wispr puts your clipboard back only ~0.5 s after its own paste, so ⌘V pasted what Wispr
  had just written ("Paste.").
- Fix: when Wispr sent the command, paste now waits for that, like copy and cut (up to 1 s). If Wispr
  never puts the clipboard back, Pilot doesn't paste and says "Wispr hasn't put your clipboard back
  yet, so pasting would type what you said. Say it again".
- Tested live in TextEdit with "CLIPBOARD TEXT" copied: "Pilot" … "paste" pasted "CLIPBOARD TEXT"
  (ran in 550 ms). The test is moved out of your usage log like the others.

## 31 Oct: The website is live at https://nohandspilot.vercel.app
- Stats refreshed from your log: 637 commands, 28 to 30 Oct, 397 ran, 22 chains, median match 1.1 ms.
  My live tests for this round went through Wispr into the same log (29 commands from 30 Oct 23:26
  on, all my test phrases); they're moved, unchanged, to `usage-tests.jsonl` next to it, with a
  backup of the whole log as `usage.jsonl.bak-31oct`, so the site counts only your own use.
- Vercel project `nohandspilot` (Vite, Root Directory `web`). The build reads files outside `web/`
  (commands.json, Brain.swift and the README for /try), so it deploys from the repo root, and
  `.vercelignore` uploads only those and `web/`, not the 500 MB app build.
- Checked live with Playwright: / and /try load (200), /try works on reload, og.png, favicon.svg,
  stats.json and robots.txt load, the link-preview tags carry the absolute URL, the autoplay chain
  finishes on /try (again after a reload), no sideways scrolling and no console errors at 1440×900 and
  390×844. Screenshots looked right.
- README has the live URL. demo.md is a new 2-minute script with the wake word, numbered ties, copy
  link, Apple Music, editing by phrase and Terminal.

## 31 Oct: Select, copy, cut and delete text and links
- Keyboard edits, anywhere, and they chain: select word / last word / last N words (⌥⇧← × N, a new
  `repeat` on keys commands), select line / to start / to end of line, select paragraph (⌥↑ ⌥⇧↓),
  cut / cut that / cut it (⌘X), copy that, delete that / it / selection (⌫), delete word / last N words
  (⌥⌫ × N), delete line (⌘⌫). Copy, paste, select all, undo and redo were already there.
- Links: "copy link Docs" / "copy the Docs link" finds the link the way click does (same ranking, only
  links), reads its `AXURL` and puts it on the clipboard: "Copied link: <url>". A tie numbers just
  those, and "copy link 2" copies that badge. "copy page link" / "copy this link" / "copy url" in Chrome:
  ⌘L ⌘C Esc.
- "select <phrase>" in an editable field (one whose selected range can be set): selects it, ignoring
  case, the occurrence nearest before the caret (then "the" dropped from the front if that misses).
  "delete / cut / copy <phrase>" select it, then act. No such field: "select X" is the old click
  ("select Downloads"), the others say "No text field here with "X" in it". Web pages you can't edit
  aren't touched.
- Found while testing: Wispr puts your clipboard back ~0.5 s after its paste, which could wipe a link
  Pilot just copied. Commands that copy or cut now wait for that (up to 0.8 s) when Wispr sent them.
- Phrase conflicts: "select all" / "select everything", "copy" / "copy it", "paste" keep their old
  meaning (more literal words win). "select {target}" moved from click to the new select command.
- Tested live. TextEdit: "delete see you soon", "cut the lazy dog" (clipboard: "the lazy dog"),
  "select quick" (the later of 2), "copy brown fox", "select last 2 words, cut" (cut "line here."),
  "delete last 2 words", "select to start of line, copy that", "select paragraph, delete that". Chrome
  textarea: select, cut and delete by phrase. Claude's message box: select and delete by phrase.
  Chrome page: "copy link docs" → `https://example.com/docs`; "copy page link"; through the wake word
  with two "Docs" links: badges, then "copy link number 2" → `https://example.com/docs/v2`, which
  survived Wispr's clipboard restore. Finder: "select Downloads" clicked the sidebar item.
- Website: /try copies link addresses from its pages and deletes, cuts and copies phrases in Claude's
  message box; the keyboard edits say "On your Mac: presses ⌥⇧←". 36 BrainCheck cases, 36 Vitest
  cases, 5 desktop tests.

## 31 Oct: "Pilot, play Florida on Apple Music" plays it
- Before: "play X" in Music was its search (⌘F, type, Return), so nothing played. Now a new action,
  `playMusic`. First your library, through AppleScript: track name equal to what you said, then
  starting with it, then containing it (AppleScript ignores case), and it plays. Toast: "▶ <track> —
  <artist>". Not in your library: Music's search on Apple Music (the scope set to Apple Music first),
  wait up to 3 s for the search field to hold your words and a "Song · …" result in Top Results, move
  the pointer onto it (that's when its play button exists: an `AXCheckBox "Play"`), press it. Toast "▶
  <song> — <artist> (Apple Music)". Otherwise the results stay on screen and the toast says it couldn't
  press play. Found while building it: the subtitle's "·" sits between narrow no-break spaces (U+202F),
  and pressing a result opens its album instead of playing.
- Phrases: "play {query}" in Music, plus "on/in Apple Music" and "on/in Music" from any app ("apple
  music" is now a name for the Music app). "play lofi beats on YouTube" is still YouTube; "search for X"
  in Music still only searches; bare "play" / "pause" are unchanged. "the song" in front is dropped.
- Automation: `NSAppleEventsUsageDescription` in the Info.plist. Pilot checks the permission without
  waiting, so the one-time "Pilot wants to control Music" prompt never holds up a command; until it's
  allowed (or if it's refused), "play X" goes straight to Apple Music's search and the toast says how
  to allow it. Setup docs and the site's setup steps mention the prompt.
- Tested live through the wake word: "play Florida on Apple Music" → `played "Florida!!! (feat.
  Florence + the Machine) — Taylor Swift" in 142 ms`. "play Bohemian Rhapsody on Apple Music" (not in
  the library) → no library match, Apple Music search, the first song's play button: Music's player
  showed "Bohemian Rhapsody" and Pause. The prompt appeared on the first try and was answered with
  Allow at 23:59 (TCC: dev.jsurya.pilot → com.apple.Music allowed).
- 10 new BrainCheck and Vitest cases; /try says "On your Mac: plays "Florida" from your Music library,
  or the first song Apple Music finds".

## 30 Oct: Clicking a name that matches two or more things
- Before: "N matches for X. Say "show numbers"". Now Pilot puts numbered badges on just the tied
  matches, top to bottom then left to right, and says `2 × "Sign in": say "click 1" or "click 2"` (3 or
  more: `"click 1" to "click N"`) as a ✓ toast, not a ⚠︎. "click 2" presses that badge through the
  usual badge path; so do "click the first / second / third / last one" (and "first", "last") while
  badges are up. Menu items have no frame to badge: a tie of only menu items keeps the old message.
- Website: /try does the same (it used to refuse), with tests for the tie, "click 2", "the first one",
  "the last one" and a number that isn't there. 3 new BrainCheck and Vitest cases ("click the second
  one" → click "second one").
- Tested live on a local page with two "Sign in" links in Chrome, through the wake word: "click sign in"
  → both badged (`AXLink "Sign in", AXLink "Sign in"`, no error); "click number 2" → the bottom one
  (`#bottom-sign-in`); again, "click the first one" → the top one (`#top-sign-in`). Wispr wrote "click
  two" as "Click to" once, which then clicked nothing (6 menu matches, the old message).

## 30 Oct: The wake word hears only "Pilot"; Wispr writes every command
- Change of plan: the wake word stays (you're recording the demo with it). The removal is undone with
  `git revert` (WakeWord.swift, the mic and speech keys, the menu item, listen/dictate, the tests and
  the copy are back); the Terminal fix stays.
- The rule now: the only word Pilot acts on from its own speech recognizer is "Pilot". Every word after
  it comes from Wispr Flow. Nothing Apple's recognizer transcribes besides the name is ever run, typed,
  joined into a command or logged.
- How: the moment the name is heard, the transcript is cancelled (Apple transcribes nothing after it)
  and Wispr starts. "🎙 Listening…" shows when Wispr's mic is on (0.37 s). The end of a command (1 s of
  quiet) and of a dictation (2 s) come from the mic's loudness, counted only from when Wispr's mic is
  on. Wispr's paste is the command; a leading "Pilot" in it is dropped (`Brain.wakeCommand`). Nothing
  from Wispr in 2.5 s, or nothing said: nothing runs, "Didn't get that from Wispr. Say it again" (or
  the Secure Keyboard Entry message if secure input is on). Gone: running Apple's words, the one-breath
  join (`joinWake`), ending early on Apple's words (`isCommand`), and logging what Apple heard (the
  log says "heard the name").
- With secure input on, the Terminal clipboard fallback takes the wake-word paste too (it doesn't start
  with "Pilot"): erased and run.
- Tested live (`say` through the speakers, both mics hear it): "Pilot" … "open Chrome, new tab, search
  for Docker networking" ran all three from Wispr's text ("Open Chrome, new tab, search for Docker
  networking."), stopped 6.1 s after the name. "Pilot" then silence: stopped after 6.4 s, "nothing
  said", nothing ran. "Pilot" … "dictate" … "Hello from the wake word." typed exactly that into
  TextEdit. "Pilot" … "open Finder" in Terminal with Secure Keyboard Entry on: read from the clipboard,
  erased from the prompt, Finder came forward.
- BrainCheck and Vitest: the 14 join cases are now 7 `wakeCommand` cases (a scrap like "Rome." runs
  nothing). Copy everywhere says: with the wake word on, Pilot listens on-device for its name only, then
  starts Wispr Flow; Wispr transcribes every command. The usage chart's "Pilot's own hearing" is now
  explained as commands the wake word started, in Apple's words, before 30 Oct. Demo script: first day
  28 Oct; the tip is "say Pilot, wait for 🎙 Listening…, then say the command".

## 30 Oct: "Pilot, …" in Terminal, with Secure Keyboard Entry on
- Your report: "Pilot, <command>" with Wispr does nothing in Terminal. Confirmed:
  `defaults read com.apple.Terminal SecureKeyboardEntry` = 1, and while Terminal is in front
  `IsSecureEventInputEnabled()` is true (now logged on every app activation: `Front: Terminal, secure
  input on`). Wispr still pastes with ⌘V (it doesn't type keystrokes), but neither tap sees it: the
  text landed at the prompt and the log had no `Cmd+V seen` line. With Secure Keyboard Entry off, the
  session tap sees the ⌘V and swallows it, as in other apps.
- Wispr puts its text on the clipboard marked `org.nspasteboard.ConcealedType` (a ⌘C from Terminal
  isn't), pastes, and puts your clipboard back ~0.5 s later. Fallback: while secure input is on or a
  terminal is in front, Pilot polls the clipboard's change count (every 50 ms). New concealed text from a
  running Wispr, one line, that a tap didn't catch by the time Wispr restores the clipboard: if it starts
  with "Pilot", Pilot sends exactly that many Backspaces (never Ctrl+U) and runs it as a Wispr command.
  Once per change count; non-Pilot text is never touched.
- Tested live: Wispr's own hands-free link plus `say` through the speakers, in a spare zsh window.
  Secure on: "Pilot, open Chrome" (erased, Chrome came forward), "Pilot, new tab" (a new Terminal
  window), "ls minus la" (`Ls -la ` stayed at the prompt), my own ⌘V of "Pilot, open Finder" (pasted,
  nothing ran). Secure off: the same three through the tap, no double run; own ⌘V "not Wispr,
  ignored". VS Code's terminal: secure input off, the tap swallowed "Pilot, open Chrome" and passed
  "ls minus la" through. iTerm2 isn't installed. Posted Backspaces do reach Terminal with secure input
  on, so the "can't see Wispr" warning wasn't needed; the menu says "Secure input is on" while it is.
- Your Secure Keyboard Entry setting is back on, as it was.

## 30 Oct: Wispr is the only ears (Apple's speech recognition removed)
- Pilot never opens the microphone. `WakeWord.swift` is gone (git history keeps it), with every
  Speech and AVFoundation import, the Microphone and Speech Recognition keys in the Info.plist, the
  "Listen for Pilot" menu item, the wake-word join (`Brain.joinWake`) and its training sentences.
  `grep -ri "SFSpeech\|AVAudio\|Microphone\|SpeechRecognition" app/` (outside the build output) finds nothing.
- The commands `listen_on`, `listen_off` and `dictate` are out of commands.json; "start listening"
  and "dictate" now say "Didn't catch". A Wispr paste goes straight to `handle`. For no hands, use
  Wispr Flow's own hands-free mode.
- "play" / "pause" no longer wait 0.7 s after Pilot stopped Wispr (Pilot never starts or stops it now).
- The menu line is now "Catching "Pilot, …" from Wispr" (it never listened).
- Website: How it works, the /try setup steps and the design notes say "Pilot never opens your
  microphone. Wispr Flow is the only thing that listens." Past usage stays honest: the "voice" source
  is labelled "Pilot's own hearing (removed 30 Oct)". The demo script's first day is now 28 Oct.
- Rebuilt and relaunched: Accessibility still granted (the log says `Accessibility: true`);
  `--run "start listening"` doesn't match, `--run "volume up"` ran in 78 ms. BrainCheck passes;
  220 Vitest tests pass (the 28 wake-word and training cases are gone).

## 29 Oct: Website, checkpoint 4: polish, ready to ship
- Lighthouse on the built site, both routes, phone and desktop presets: 100 everywhere except `/try`
  on a phone (performance 94, a 3.0 s largest paint on a throttled phone) and the landing page on a
  desktop (performance 99). Fixed on the way: a real `robots.txt`, no canonical tag that would have
  called `/try` a copy of the home page, 24 px hit areas behind the traffic lights and tab close
  buttons, and the address bar's label.
- A Mac drawn smaller than 75% (the hero, phones) is now a picture: `inert`, so it adds no specks to
  tap and no stops to Tab through. The full-size chips and command bar drive it, and clicking the
  hero's opens `/try`.
- Keyboard: every stop on both pages shows a ring (the command bar now too), "/" focuses the bar, and
  the HUD speaks to screen readers once you've done something.
- No sideways scrolling at 1440, 1024, 768 or 390 px, in either theme, on either route.
- Copy re-read against the docs: the desktop's About menu now says the Brain is a TypeScript port
  passing all of its Swift tests (not "the real Brain"), and the demo placeholder no longer promises
  the video shows the same commands.
- README: a Website section (run it, test it, refresh the stats).

## 29 Oct: Website, checkpoint 3: the landing page
- The hero keeps the approved headline and puts the live Mac next to it: it plays the chain, YouTube,
  numbers, click 3, pause and study mode, round and round, until you touch it, and only while it's on
  screen. On a laptop it's all above the fold: the Mac, its HUD and the command bar.
- Then: why I built it (a by-hand / with-Pilot table of six everyday things), how it works (Wispr →
  Pilot catches the paste → the Brain → Accessibility; median match, offline, untouched dictation; the
  wake word; teaching by voice), the demo video slot (`DEMO_VIDEO_ID` in `web/src/config.ts`; until it's
  set the poster says the video is on its way and points to the Mac above), my real usage, the Wispr
  usage card (`web/public/wispr-usage.png`, a dashed frame until it's there), a get-it band with the
  three install steps, and the footer (not affiliated with Wispr, MIT, @jsuryacodes).
- My real usage comes from `stats.json`: commands, how many ran, chains, median match and run times,
  commands per day, how they reached Pilot (Wispr, Pilot's own hearing, the command bar), and the most
  used commands by the phrase you say. Every chart is one series in one neutral ink (the amber stays
  Pilot's), with hover and keyboard tooltips and a table for screen readers.
- Copy checked against the docs. One correction to the brief: with the wake word, Wispr doesn't always
  write the whole command. Said in one breath, the first words come from Pilot's own hearing, because
  Wispr's mic takes ~0.36 s to open (README, the 29 Oct measurements). The page says that.
- Link previews: title, description and `og.png`, with the absolute address filled in from Vercel's
  production domain at build time.
- A test checks that every command the page shows runs in the real Brain (14 phrases); 248 tests in
  all, plus the 2 browser tests.

## 29 Oct: Website, checkpoint 2: a Mac in the browser (/try)
- `/try` is a Mac that runs commands through Pilot's real Brain and commands.json. It has a menu bar
  with a live clock and Pilot's airplane menu ("Today: N commands, on this page"), a drawn wallpaper,
  and a Dock with original icons that magnifies and bounces apps as they open. Windows can be dragged,
  focused, minimised, made full screen and closed. It follows the site's theme (light or dark Mac).
- About 30 commands really happen there: open, switch to, quit and hide apps, switch back; new,
  close, reopen, next, previous and numbered tabs; search; sites by name; YouTube results, then play and
  pause ("Already paused"); scrolling; full screen and minimise; show numbers, click N, click by name;
  VS Code's terminal, Claude's sidebar, new chat and "ask Claude"; Finder folders and Settings panes;
  study mode and coding mode; "what can I say?" (searchable, and its phrases run when clicked); open
  NoHandsPilot. Anything else that matches says what it would do, from commands.json: "On your Mac:
  presses ⌘=".
- It behaves like Hands: a link opens in a new tab, opening an app with no window opens one (Finder
  after "switch back"), numbers go when another app comes forward or after 20 s, two things with the
  same name are refused, and the errors read like Pilot's ("No previous app yet").
- Command bar: type, dictate into it with Wispr (a paste runs by itself, like the real bar), use the
  browser's speech recognition, or tap a suggestion. The suggestions step through: open Chrome → new
  tab → search → the chain → play lofi beats on YouTube → show numbers → click 3 → pause the video →
  switch back → study mode → open NoHandsPilot → what can I say. "/" focuses the bar. The HUD shows a
  chain step by step, with the measured match time.
- The NoHandsPilot window: Download, View on GitHub, the setup steps in order (Gatekeeper,
  Accessibility, Input Monitoring if needed, Wispr's dictionary, the ⌃⌥P test, the optional wake word's
  Speech Recognition and Microphone), and Build from source.
- First visit: an empty desktop, then it types and runs "open Chrome, new tab, search for Docker
  networking" by itself (done in about 3.5 s) and stops for good once you click or type. Phones get the
  Mac scaled down, with the controls below it.
- Tests: 51 command → effect cases in Vitest (234 with the Brain's), and a Playwright test that the
  first visit's chain finishes within 5 s.
- Followed the code over the brief: "pause the video" now comes after "click 3" (the YouTube command
  opens the results, and nothing plays until you click one, as in docs/demo.md), and "install Pilot"
  isn't a command.
- Found while writing the setup steps: since macOS 15, right-click → Open no longer opens an app that
  isn't notarized. The steps say System Settings → Privacy & Security → Open Anyway, and keep
  right-click → Open for macOS 14 and earlier.

## 29 Oct: Website: light mode, and a System / Light / Dark choice
- Your ask: a light theme, chosen directly from three options, not a button that cycles. The nav now
  has three side-by-side buttons (radio buttons, so arrow keys work too). System follows your Mac and
  changes with it; Light and Dark are remembered. The theme is set before the page first draws, so it
  never flashes dark first. Checked in a browser: Dark sticks after a reload, System forgets it.
- Light is the same two colours swapped (ink on paper) with a deeper amber (#A85700), because the
  bright one is under 2:1 on paper. Every text colour is at least 4.5:1 on every surface in both
  themes. The colour tokens are now named for their role (`canvas`, `surface`, `fg`), so one class
  works in both. DESIGN.md has both palettes.
- On phones the nav keeps only the logo and the theme choice (the hero's "Try it" is right below).

## 29 Oct: Website, checkpoint 1: foundation (waiting for your design OK)
- `web/`: Vite, React, TypeScript (strict), Tailwind, Framer Motion, Vitest, ESLint and Prettier;
  `npm run dev / build / test / preview / lint / format / og`. Two routes without a router library:
  `/`, and `/try` (a placeholder until the desktop is built). `web/vercel.json` serves `/try` on reload.
- The Brain in TypeScript (`web/src/brain/brain.ts`): a line-by-line port of `Brain.swift` that reads
  `commands/commands.json` itself through a Vite alias, so the site and the app share one copy. All 183
  BrainCheck cases are in Vitest and pass: the 165 checks, 6 teaching plans, 5 one-off checks, 6 training
  sentences and the speed check, wake-word joins and menu items included. The demo chain plans in about
  1 ms in the browser.
- `scripts/export-stats.mjs`: usage.jsonl → `web/public/stats.json`, aggregates only (never the text or
  the error messages, which can quote it). From your log now: 551 commands, 28 to 29 Oct, 350 ran, 17
  chains, median match 1.1 ms (p95 96.8 ms), checked against jq. `stats.example.json` holds made-up round
  numbers, and the site labels them "Sample data" whenever it falls back to that file.
- Design (`web/DESIGN.md`, tokens in `web/src/index.css`): ink background, paper-white text, and one amber
  signal (#FFB02E) used only while Pilot hears or acts. Fraunces for headlines, Instrument Sans for text,
  JetBrains Mono for commands, all self-hosted.
- Logo: a raised hand with a sound wave through the palm, as an app-icon tile (`web/public/favicon.svg`):
  the favicon, the nav mark, the dock icon and the link preview. `web/public/og.png` is rendered from the
  site's own fonts by `npm run og`.
- The hero types real commands into a Pilot bar and shows what the Brain made of each: the HUD line from
  the commands' `say`, the measured match time, and the keys each step would press on a Mac.
- Found while porting: "install Pilot" isn't a phrase in commands.json and "pilot" is a filler word, so
  the site answers it with "Didn't catch"; "open NoHandsPilot" opens the app's window instead. Your log
  starts on 28 Oct, so the site won't repeat the demo script's "every day since 25 October".

## 29 Oct: "click Relax" / "click Feel Good" in Apple Music
- Your test (04:49): "Pilot, click relax" and "click feel good" on Music's Home page said "Couldn't
  find". Same for "click your essentials" (04:48).
- Cause: those tiles aren't buttons. Music exposes each one as a group named "Relax", "Feel Good", …
  that answers the press action, and click only looked at buttons, links, tabs, rows, cells, fields
  and plain text.
- Fix: any element with a name that answers press counts too (only named ones are asked, so plain
  containers stay out). "show numbers" now badges those tiles as well.
- Checked on Music's live tree without pressing anything: before, no match for "relax" or "feel
  good"; now exactly one each (the tile), and the 10 tiles on screen are the only additions. Chrome's
  page (1,873 nodes) walks in the same time as before.

## 29 Oct: "Pilot" no longer ignored after arrow-key shortcuts
- Your test (04:34): after "Pilot, scroll right across space" ran, the next six "Pilot"s did nothing.
  The log said `heard "Pilot" with fn held (Wispr's key)`, but Wispr's history has no session then,
  so fn wasn't pressed.
- Cause: Pilot ignores "Pilot" while you hold Wispr's fn key, and it read that from macOS's modifier
  flags. Those go stale. Pilot sent Ctrl+→ with Control still on in the key up, so macOS kept Control
  and fn "held" until your next real key press. Reproduced on an unused key (Ctrl+F16): stuck until
  someone touched the keyboard. That test also dropped 4 of your "Pilot"s (04:45:31–42). Your own
  → key does it to fn too: pressing it to skip in a video was enough to block "Pilot".
- Fix 1, in every shortcut Pilot sends (and its Cmd+V / Cmd+C): the key up carries no modifiers, as
  if you'd let go. Checked through the app: "scroll to top" (Cmd+↑) now leaves the flags clean. Same
  cause, also fixed: a click Pilot made while they were stuck had Control set (a right-click).
- Fix 2: the wake word checks the fn key itself (key 63), which no shortcut changes. It stayed "up"
  through every stuck stretch above. Not yet checked with your finger on fn (setup step 8).
- Your run after the fix (04:55–04:58): 14 "Pilot"s logged, none dropped as `fn held`. "Pilot" 2 s
  after "scroll right across space" (the 04:34 failure) worked, and the Space still switched (Wispr's
  history: Music in front before, Chrome after).

## 29 Oct: "Pilot" heard every time, the right words, sooner
- Why it missed: Wispr's history shows that in one breath Wispr only catches the last word or nothing (11 of your
  last 31 sessions were empty). So Pilot waited 2.5 s for text that never came, and its timing guess put Wispr's
  word in the wrong place: "open Wi-Fi settings" + Wispr's "Settings" ran "open Settings", and "hide numbers" +
  "Numbers" showed the numbers.
- Apple's recognizer now learns Pilot's own sentences: a custom language model built on this Mac from every
  phrase with example values (3,502 sentences, 2.6 s at launch, rebuilt only when commands or taught phrases
  change). Tested offline on 70 of your "Pilot, …" recordings from Wispr's history: "Pilot" heard in all 70 with
  or without it, and the words after it exactly right in 52 (45 before). Where Wispr misheard, it was often right:
  "scroll left across space" where Wispr wrote "grow left across base". 50 other dictations: no false "Pilot".
  On synthetic Indian English voices (Rishi, Aman, Tara): "Pilot" in 18 of 18 clips (16 before), and "scroll
  write across space" became "scroll right".
- Live listening fixes: "Pilot" anywhere in the transcript counts (before, only the last two words were checked,
  so a word first heard as "pile" and corrected later was missed); "Pilots", "Pilot's", "Pilate" and "Violet" count
  (Violet came up on your recordings); a result that packs "Pilot scroll" into one piece is split into words; no
  deaf half-second when the recognizer restarts; the once-a-minute restart waits for a pause; and if the mic
  stops (sleep, a device change), Pilot restarts it within ~2 s (checked by switching the input device).
- Joining: Wispr's words are lined up with the end of Apple's, word by word, instead of by timing. All 6 wrong
  joins from your 03:27 log now come out right (BrainCheck). If none of Wispr's words match, Apple's go first.
- Faster: Pilot measures your voice level, so it knows when you'd finished before Wispr's mic opened (0.37 s
  after its link). Then it runs at once instead of waiting for Wispr. A whole command ("scroll up") ends 0.4 s
  after the last word, once the mic has also been quiet 0.6 s; anything else ("open …") after 1 s. That second
  check came from a test: "hide numbers" stalled at "hide", and Cmd+H hid Chrome. If Wispr heard you, its text is
  awaited for 1.2 s (was 2.5 s; 95% of its 2,598 pastes take under 1.1 s).
- Measured live through a virtual audio cable (Rishi, Aman, Tara voices; Wispr kept on the real mic, so it heard
  the room, not the test): first run 12 of 12 wake words; second run 7 of 12, the 5 misses all in one 40 s
  stretch while someone was using the Mac (Chrome had a password field focused, Wispr's mic heard speech). Not
  confirmed why. One guess is Wispr's fn key held: Pilot ignores "Pilot" then, and now logs it ("with fn held").
  Commands where you'd finished before Wispr's mic opened ran 0.9–1.2 s after the speech ended. Where Wispr
  heard you, expect ~1.3 s (its text, ~0.4 s, instead of the 1.2 s wait the cable test hit).

## 29 Oct: Play and pause the video on screen, fixes from your last test
- Your test (03:29): "play video" and "resume video" weren't phrases, so nothing happened. Now "play", "pause",
  "resume", "play / pause / stop the video", "pause it", "stop music" and "play pause" (toggle) all work.
- "pause" only pauses and "play" only plays: Pilot first looks for the player's own button in the front window.
  YouTube names it for what it does now ("Pause keyboard shortcut k" while playing), as do Netflix, Spotify,
  Music and QuickTime. So "pause" on a paused video says "Already paused" instead of starting it. With no player
  on screen it presses the media key, which goes to whatever is playing (Spotify or Music in the background).
- Wispr pauses what's playing while it records ("Pause music while dictating" is on in your Wispr settings) and
  resumes it when it stops. So after Pilot stops Wispr, play/pause waits until 0.7 s after the stop, or Wispr's
  resume would undo it.
- Also from that log: "show number" opened the Numbers app (now shows the badges), "open Bluetooth" / "open
  Wi-Fi" / "open network settings" didn't match (now open those panes; the Network pane ID was checked against
  the system's settings extensions), and "open Spotlight" waited 5 s for an app (now Cmd+Space).

## 29 Oct: Wispr back for "Pilot …", started the instant Pilot hears the word
- Your ask: keep Wispr (mandatory) and trigger it straight after "Pilot", like the fn key. Your
  02:33 tries with Apple alone all failed ("scroll write across space", "scroll right Cross space").
- Measured (CoreAudio's per-app "mic running" flag, polled every 1 ms): Wispr's mic is on 349–375 ms
  after its link and 352–373 ms after a simulated fn press, every time, because Wispr opens its mic
  fresh for each dictation. So fn is no faster, and Pilot keeps the link. Apple's recognizer adds
  ~0.3 s before it reports "Pilot", so Wispr hears from ~0.6 s after the word.
- Now: Pilot starts Wispr in the same moment it hears "Pilot", before logging or showing anything.
  If you pause a beat, Wispr hears the whole command. In one breath, Pilot notes which words Apple
  heard before Wispr's mic was on and puts them in front of Wispr's text ("scroll right" + "Across
  space."). Wispr's first word can be the end of a word it half heard ("Rome" for "chrome", "Cross"
  for "across"): then Pilot's whole word is used. If the join doesn't match a command, Pilot's own
  words are tried. 8 BrainCheck cases for the join (`Brain.joinWake`).
- If Wispr can't have heard any of it (a short "Pilot mute"), Pilot runs its own words at once and
  drops whatever scrap Wispr sends in the next 1.5 s. If Wispr sends nothing within 2.5 s, Pilot's
  own words run. Wispr's text of a wake command is never typed (it's dropped for 4 s).
- Wispr ignores a start sent within ~0.3 s of a stop (it keeps recording that long), so "Pilot
  dictate" now waits until 0.5 s after the command's stop before starting Wispr again.
- With secure input on (Terminal's Secure Keyboard Entry), Pilot can't catch Wispr's paste, so it
  doesn't start Wispr and runs its own words, as before. Untick it to get Wispr in Terminal too.
- From Wispr's history: a session with no speech pastes nothing; Wispr's text arrives 0.25–0.55 s
  after the stop, and it keeps recording ~0.3 s past it. A command now runs ~1.5 s after you stop
  speaking (was ~0.8 s without Wispr).

## 28 Oct: "Pilot scroll right across space" in one breath, run instantly
- Your ask: no wait between "Pilot" and the command. Wispr can't do that: it only starts once Pilot
  has heard "Pilot" (~0.3 s after the word) and takes up to ~0.3 s more to record, so the first words
  were lost ("Cross space", "Across spaces", "Space" in the log). Its links are start, stop and
  switch-mic only, with no cancel, so Pilot can't race it and call it off either.
- Now Apple's offline recognizer, which already hears everything for the wake word, also hears the
  command. Pilot runs it after a 0.5 s pause (checked 10×/s, was 5×). Measured from a recording: the
  last word reaches Pilot ~0.3 s after it's said, so it runs ~0.8 s after you stop, with no Wispr
  start, transcription or paste in between.
- So no paste either: these commands can't be typed into a text field, and they work in Terminal
  even with Secure Keyboard Entry on (the warning from the last entry is gone with Wispr's start).
- Wispr still does "Pilot dictate" and anything said with its key held. 4 BrainCheck cases for
  unpunctuated one-breath text (Apple adds no commas; "Pilot open Chrome new tab" still chains).

## 28 Oct: Fix commands typed into text fields, end commands sooner
- Your test: with the cursor in a text field (Terminal, WhatsApp, Chrome) the command got typed. The
  logs showed three separate causes, all invisible outside a text field because Wispr's paste lands
  nowhere there:
  1. A "Pilot, …" command that didn't match ("Pilot, swipe right across space", twice in WhatsApp)
     was passed through as text on purpose. Now it shows "Didn't catch" and is never typed.
  2. After "Pilot", if Apple's recognizer heard nothing (19:11:53: "nothing said" after 6.2 s), Pilot
     stopped expecting a command, so Wispr's text was typed. Wispr's next text now always counts as
     the command. Apple's recognizer also restarts if it stops mid-command, and "dictate" with
     listening off now hears the pause instead of always stopping at 6 s.
  3. Terminal has Secure Keyboard Entry on here. macOS then hides every keystroke into Terminal from
     other apps, Wispr's Cmd+V included (Terminal pasted at 18:57:11, Pilot saw nothing). No app can
     catch it, so "Pilot" now shows a ⚠︎ toast instead of starting Wispr. Untick it in Terminal's
     menu to use Pilot there.
- Latency, measured: Wispr starts 20–270 ms after Pilot's link, and Apple's recognizer reports
  "Pilot" ~0.3 s after the word ends. The quiet that ends a command is now 0.8 s (was 1.2 s).

## 28 Oct: No hands: say "Pilot" to start Wispr
- With listening on (Pilot menu → Listen for "Pilot", or "start listening"), Pilot hears the word
  "Pilot" with Apple's offline speech recognizer (on this Mac, Indian English), then starts Wispr
  Flow's hands-free mode through Wispr's own link (`wispr-flow://start-hands-free`) without taking
  focus. You say the command; after 1.2 s of quiet Pilot stops Wispr (`stop-hands-free`), Wispr types,
  and Pilot runs it as usual. Wispr still transcribes every command: this only replaces the key.
- Wispr starts after you've said "Pilot", so its next text counts as a command without the word. If
  that text isn't a command (a false wake), it's dropped, not typed. Holding Wispr's Fn key never
  triggers it (you're already dictating).
- "Pilot, dictate": Wispr types what you say next (not run as a command) until you pause 2.5 s.
- Found by reading Wispr's app: those links exist, and Wispr reads its Fn key at the hardware level,
  so a key press sent by Pilot wouldn't have worked. Checked here: the start link doesn't take focus,
  and the stop link makes Wispr type.
- Mic and speech permission asked once. Off unless switched on; the mic is open while it's on.
  144 BrainCheck cases. Needs your voice test.

## 28 Oct: Scroll across spaces
- Your design: plain "scroll …" stays inside the app; adding "across space(s)" goes across, like the
  three-finger swipe. "scroll right across space" = the full-screen app or desktop on the right
  (Chrome → WhatsApp), "scroll left across space" = on the left, "scroll up across space" = Mission
  Control, "scroll down across space" = the current app's windows (what three fingers up/down do).
- Uses macOS's own shortcuts (Control+arrow keys), which are on by default. No "swipe" phrases.
- Checked here: from the Desktop space, "scroll right across space" moved to Chrome (58 ms).
  138 BrainCheck cases.

## 28 Oct: Fix scrolling (it never worked in full-screen Chrome)
- Your test: "scroll down" / "scroll up" on LinkedIn said "Scrolled" but nothing moved. Cause: scroll
  events go to whatever is under the pointer, and Pilot aimed at the first window the app has on
  screen. In full screen that's Chrome's thin tab-strip window, so the pointer went to the tabs (it
  was sent to y=53 of 982) and the page never moved.
- Fix: the pointer now always goes to the middle of the window you're working in (the focused
  window, from Accessibility), then scrolls. "scroll left" / "scroll right" are new.
- Verified here on a test page that reports its own scroll position: down + right → 480, 480;
  left + up → 0, 0. About 140 ms per scroll.
- Tried and dropped: checking whether the content moved, so the toast could say "nothing moved".
  Chrome doesn't update element positions reliably after a scroll (3 false "nothing moved" out of
  7), and a false error is as misleading as a false ✓. 134 BrainCheck cases.

## 28 Oct: Commands on selected text (4)
- Select text anywhere, then "Pilot, search this" / "google this" (Google), "translate this" (Google
  Translate to English), "define this" / "what does this mean" (the Dictionary app, offline), or
  "ask Claude about this" (new Claude chat with the selection, sent).
- The selection is read once when the command starts, before any app switch: Accessibility first
  (AXSelectedText, or the text-marker range on web pages), else Cmd+C with the clipboard put back
  exactly, every item and type (tested on a private pasteboard). If Cmd+C copies nothing, the
  clipboard isn't touched and the toast says "Select some text first". After a Wispr paste the copy
  first waits for Wispr to put your clipboard back.
- Matching rule: free text needs at least one non-filler word, so "search this" is no longer a web
  search for "this" (and Chrome's own search doesn't grab it). "search for this week's news" still
  searches.
- Typing long or multi-line text now pastes it (clipboard restored after), so a newline can't send a
  chat message early.
- Checked through the app with nothing selected: "Select some text first", clipboard change count
  unchanged. 132 BrainCheck cases.

## 28 Oct: Open anything by name (3)
- Files and folders through Spotlight: "open file resume", "open the hackathon folder", "open document
  …", "find file …", "show resume in Finder". A file/folder word is required, so "open resume" is never
  a file search and a misheard app name can't open a random file. Picks the most recently used match
  under your home folder (skips ~/Library, hidden folders, node_modules); the toast names the file and
  its folder. Inside VS Code, "open file …" still means VS Code's quick open.
- Matches whole words, not substrings. Measured: substring matching made "irs notes" match "fdt-3
  unit-notes(first half).pdf" and took 47 s for "a"; whole words find Jaya_Surya_Resume.pdf for
  "resume" in 52 ms, and every test query took 21–256 ms. Trade-off: "screenshots" won't match
  "Screenshot".
- Downloads, Documents, Desktop, home folder, Applications open in Finder from any app ("open
  downloads", "show documents"). Inside Finder its own shortcuts still win.
- Settings panes: "open bluetooth / wi-fi / sound / display / battery / notifications / keyboard /
  privacy / accessibility settings". Each URL was opened here and the System Settings window title
  checked (all 9 matched). Non-web links now open in their own app instead of Chrome.
- Checked through the app: "show nohandspilot in Finder" found it in 38 ms; "open bluetooth
  settings" brought System Settings forward in 122 ms. 121 BrainCheck cases.

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
- Checked here through the app: teach, all three refusals, forget, forget-unknown. 107 BrainCheck cases.

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
- [ ] Your batched test of the 28 Oct features (docs/setup.md section 6) → fix whatever it shows
- [ ] Website playground (reuses commands.json and learned.json; port the Brain's matching rules to JS)
