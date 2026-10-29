# Build log

Newest first. Each entry matches a commit on `main`.

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
