# 2-minute demo script

Every command below is covered by `swift run BrainCheck`. Rehearse once and check each one works on
your Mac before recording.

With the wake word on, say "Pilot", wait for the 🎙 Listening… toast, then the command. Wispr writes
every command; Pilot only listens for its name.

| Time | Show | Say |
|---|---|---|
| 0:00–0:12 | Face/desk, hands on trackpad | *(voiceover)* "Wispr Flow gave me a keyboard I can talk to. But I still reach for the trackpad to open apps, switch tabs and scroll. Pilot gives me hands." |
| 0:12 | Hands off the desk, empty desktop | "Pilot" … "open Chrome, new tab, search for Docker networking." |
| 0:22 | Results page | "Pilot" … "scroll down." |
| 0:27 | A page with two links of the same name (e.g. two "Sign in") | "Pilot" … "click sign in." Badges 1 and 2 appear on just those two: "2 × "Sign in": say "click 1" or "click 2"". Then "Pilot" … "click the second one." |
| 0:40 | | "Pilot" … "copy link docs." Toast "Copied link: …". |
| 0:47 | | "Pilot" … "play Florida on Apple Music." It plays; toast "▶ Florida!!! (feat. Florence + the Machine) — Taylor Swift". |
| 0:57 | | "Pilot" … "pause." |
| 1:00 | Click into Claude's message box; dictate normally with Wispr's key: "Explain Docker bridge networks like I'm five, see you soon." | Text types normally: **anything not starting with "Pilot" is untouched.** |
| 1:10 | | "Pilot" … "delete see you soon." Just that phrase goes. Then "Pilot" … "select last 3 words, cut." |
| 1:20 | | "Pilot" … "press enter." Claude answers. |
| 1:25 | Terminal (Secure Keyboard Entry on) | "Pilot" … "open VS Code, toggle terminal." Nothing is left at the prompt. Then "Pilot" … "switch back." |
| 1:30 | The submission form | "Pilot" … "take a screenshot." Then "Pilot" … "click Add images, upload the screenshot." The picker opens, picks it and closes by itself. (To take it back: "Pilot" … "remove the screenshot".) |
| 1:35–1:50 | Pilot menu → "Today: N commands (M via Wispr)", then the site's usage section | *(voiceover)* "No AI round-trip: the median match in my log is 1.1 milliseconds, offline. I've used it every day since 28 October, and these are the real numbers." |
| 1:50–2:00 | nohandspilot.vercel.app, then Wispr → Insights → Your usage | *(voiceover)* "Try it in your browser. Built by voice with Wispr, for Wispr." |

## Before recording

- Pilot menu → Open at Login (so it's clearly a daily tool), and say "Pilot, what can I say?" once to
  show the command list.
- Close apps that make noise; quit Pilot's command bar if it's open.
- No hands: say Pilot, wait for 🎙 Listening…, then say the command.
- If a line misfires, the toast says "Didn't catch … Try …". Add the phrase you naturally used to
  `commands/commands.json`; it applies on the next command, no rebuild needed.
