// Self-check for the Brain against the real commands.json: `swift run --package-path app BrainCheck`
import Foundation
import PilotBrain

let path = CommandLine.arguments.dropFirst().first ?? "../commands/commands.json"
let profiles: [(key: String, value: String)] = [("Jaya", "Default"), ("College", "Profile 1"), ("Jaya Surya", "Profile 2"), ("Work", "Profile 9"),
                                                ("Jaya Surya", "Default"), ("PENUMATCHA JAYA SURYA", "Profile 1"), ("Jaya Surya Penumatcha", "Profile 2")]
let brain = try Brain(json: Data(contentsOf: URL(fileURLWithPath: path)),
                      installedApps: ["Google Chrome", "Claude", "Visual Studio Code", "Finder", "Telegram", "WhatsApp", "Safari", "Terminal",
                                      "GitHub Desktop", "YouTube", "ChatGPT", "Spotify", "Music", "Numbers Creator Studio", "OBS", "Time Machine"],
                      appAliases: ["OBS Studio": "OBS", "Numbers": "Numbers Creator Studio", "Code": "Visual Studio Code"],
                      slotValues: ["profile": profiles, "folder": [("downloads", "/Users/me/Downloads"), ("documents", "/Users/me/Documents"),
                                                                   ("home", "/Users/me"), ("applications", "/Applications")]])
var failures = 0

func actions(_ text: String, app: String? = nil, trigger: Bool = true) -> [Action]? {
    if case .run(let steps) = brain.plan(text, frontmostApp: app, requireTrigger: trigger) { return steps.flatMap(\.actions) }
    return nil
}
func check(_ text: String, app: String? = nil, trigger: Bool = true, _ expected: [Action]?, line: Int = #line) {
    let got = actions(text, app: app, trigger: trigger)
    if got != expected { failures += 1; print("FAIL line \(line): \"\(text)\" [\(app ?? "-")]\n  got:      \(String(describing: got))\n  expected: \(String(describing: expected))") }
}
let chrome = Action.openApp("Google Chrome")

// trigger handling: punctuation, case, "hey", no trigger
check("Pilot, open Chrome.", [chrome])
check("pilot open chrome", [chrome])
check("  Hey, Pilot: launch Visual Studio Code!", [.openApp("Visual Studio Code")])
check("Open Chrome.", nil)
if brain.plan("Open Chrome.", frontmostApp: nil) != .notForPilot { failures += 1; print("FAIL: non-Pilot text should be notForPilot") }
check("Pilots are great", nil)
check("Pilot programs are useful.", nil)
check("open chrome", trigger: false, [chrome])

// sentences from the real usage log (28 Oct)
check("Pilot, open Chrome in a new tab and search \"hello\". ", [chrome, .keys("cmd+t"), .keys("cmd+l"), .type("hello"), .keys("enter")])
check("Pilot, open Chrome and search hello. ", [chrome, .keys("cmd+l"), .type("hello"), .keys("enter")])
check("Pilot, can you switch the Chrome profile to Jaya Surya Penumatcha? ", [.chromeProfile("Profile 2")])
check("Pilot, can you switch the Chrome profile to Jaya Surya? ", [.chromeProfile("Profile 2")])
check("Pilot, can you open a new Chrome tab? ", [chrome, .keys("cmd+t")])
check("Pilot, open a new Chrome tab. ", [chrome, .keys("cmd+t")])
check("open chrome , open a new tab and search hello", trigger: false, [chrome, .keys("cmd+t"), .keys("cmd+l"), .type("hello"), .keys("enter")])

// profiles
check("Pilot, switch to my college profile", [.chromeProfile("Profile 1")])
check("Pilot, switch to work profile", app: "Finder", [.chromeProfile("Profile 9")])
check("Pilot, change chrome profile to Jaya", [.chromeProfile("Default")])

// fuzzy app names, strict quit
check("Pilot, switch to telegrm", [.openApp("Telegram")])
check("Pilot, open VS Code", [.openApp("Visual Studio Code")])
check("Pilot, quit chrome", [.quitApp("Google Chrome")])
check("Pilot, quit chrom", nil)

// sites and search
check("Pilot, open GitHub", [.openURL("https://github.com")])
check("Pilot, go to docker.com", [.openURL("https://docker.com")])
check("Pilot, search YouTube for lofi music", [.openURL("https://www.youtube.com/results?search_query=lofi%20music")])
check("Pilot, play lofi beats on YouTube", [.openURL("https://www.youtube.com/results?search_query=lofi%20beats")])
check("Pilot, search for docker networking on stack overflow", [.openURL("https://stackoverflow.com/search?q=docker%20networking")])
check("Pilot, search for docker in chrome", app: "Finder", [chrome, .keys("cmd+l"), .type("docker"), .keys("enter")])
check("Pilot, search for docker", app: "Terminal", [chrome, .keys("cmd+t"), .type("docker"), .keys("enter")])
check("Pilot, search for chrome extensions", app: "Google Chrome", [.keys("cmd+l"), .type("chrome extensions"), .keys("enter")])
check("Pilot, ask Claude what is a docker bridge network", [.openApp("Claude"), .keys("cmd+n"), .wait(600), .type("what is a docker bridge network"), .wait(100), .keys("enter")])

// chains
check("Pilot, open Chrome, new tab, search for Docker networking.", [chrome, .keys("cmd+t"), .keys("cmd+l"), .type("Docker networking"), .keys("enter")])
check("Pilot open chrome then new tab and then scroll down", [chrome, .keys("cmd+t"), .scroll("down", 6)])
check("Pilot, scroll right", [.scroll("right", 6)])
check("Pilot, scroll to the left.", [.scroll("left", 6)])
// "… across space" moves between full-screen apps and desktops; plain "scroll" stays in the app
check("Pilot, scroll right across space", [.keys("ctrl+right")])
check("Pilot, scroll to the left across spaces.", [.keys("ctrl+left")])
check("Pilot, scroll up across the space", [.keys("ctrl+up")])
check("Pilot, scroll down across spaces", [.keys("ctrl+down")])
check("Pilot, search for salt and pepper", app: "Google Chrome", [.keys("cmd+l"), .type("salt and pepper"), .keys("enter")])
check("Pilot, open chrome, blorp, new tab", nil)
check("Pilot, open YouTube website, then scroll down a lot", [.openURL("https://www.youtube.com"), .scroll("down", 16)])

// per-app commands, "in <app>", app named mid-sentence, filler words
check("Pilot, toggle the sidebar", app: "Visual Studio Code", [.keys("cmd+b")])
check("Pilot, toggle sidebar", app: "Finder", [.keys("ctrl+cmd+s")])
check("Pilot, open the sidebar in Claude", [.openApp("Claude"), .keys("cmd+b")])
check("Pilot, close the Claude sidebar", [.openApp("Claude"), .keys("cmd+b")])
check("Pilot, um, can you please open a new tab for me", app: "Google Chrome", [.keys("cmd+t")])
check("Pilot, I want to go back", app: "Google Chrome", [.keys("cmd+[")])
check("Pilot, open the terminal in VS Code", [.openApp("Visual Studio Code"), .keys("ctrl+`")])
check("Pilot, go to tab three", app: "Google Chrome", [.keys("cmd+3")])
check("Pilot, switch to the last tab", app: "Google Chrome", [.keys("cmd+9")])

// commands aimed at an app stay in that app (real miss, 28 Oct)
let wa = Action.openApp("WhatsApp")
check("Pilot, can you search Jotir Aditya in WhatsApp? ", [wa, .keys("cmd+f"), .wait(250), .type("Jotir Aditya")])
check("Pilot, search jyothir aditya on whatsapp", [wa, .keys("cmd+f"), .wait(250), .type("jyothir aditya")])
check("Pilot, search for Jyothir", app: "WhatsApp", [.keys("cmd+f"), .wait(250), .type("Jyothir")])
check("Pilot, search for notes in Telegram", [.openApp("Telegram"), .keys("cmd+f"), .wait(150), .type("notes")])
check("Pilot, open GitHub in Chrome", [.openURL("https://github.com")])

// chains stay in the app they switched to; display names; reserved phrases (real misses, 28 Oct)
check("Pilot, can you open music and search Florida?", [.openApp("Music"), .keys("cmd+f"), .wait(250), .type("Florida"), .keys("enter")])
check("Pilot, search for Florida", app: "Music", [.keys("cmd+f"), .wait(250), .type("Florida"), .keys("enter")])
// "play X" plays in Music (30 Oct): "apple music" is the Music app; site search and bare play/pause are unchanged
let music = Action.openApp("Music")
check("Pilot, play Florida on Apple Music", [music, .playMusic("Florida")])
check("Pilot, play Florida in Music", app: "Google Chrome", [music, .playMusic("Florida")])
check("Pilot, play Florida on music", [music, .playMusic("Florida")])
check("Pilot, play Florida", app: "Music", [.playMusic("Florida")])
check("Pilot, play the song Florida on Apple Music", [music, .playMusic("the song Florida")])   // Hands drops "the song"
check("Pilot, play", app: "Music", [.media("play")])
check("Pilot, pause", app: "Music", [.media("pause")])
check("Pilot, play lofi beats on YouTube", app: "Music", [.openURL("https://www.youtube.com/results?search_query=lofi%20beats")])
check("Pilot, search for Florida on Apple Music", [music, .keys("cmd+f"), .wait(250), .type("Florida"), .keys("enter")])   // search stays search
check("Pilot, open Apple Music", [music])
check("Pilot, open finder, search for report", [.openApp("Finder"), .keys("cmd+f"), .wait(150), .type("report")])
check("Pilot, open chrome, ask claude what is jazz", [chrome, .openApp("Claude"), .keys("cmd+n"), .wait(600), .type("what is jazz"), .wait(100), .keys("enter")])
check("Pilot, open chrome, open claude", [chrome, .openApp("Claude")])
check("Pilot, can you open OBS Studio?", [.openApp("OBS")])
check("Pilot, open numbers", [.openApp("Numbers Creator Studio")])
check("Pilot, show numbers.", [.numbers(true)])

// misc
check("Pilot, pause the music", [.media("pause")])
check("Pilot, pause the video.", [.media("pause")])   // real misses, 29 Oct: no video phrases
check("Pilot, resume video", [.media("play")])
check("Pilot, play video", [.media("play")])
check("Pilot, stop the video", [.media("pause")])
check("Pilot, play", [.media("play")])
check("Pilot, play pause", [.media("playPause")])
check("Pilot, show number", [.numbers(true)])   // real miss, 29 Oct: opened the Numbers app
check("Pilot, hide number", [.numbers(false)])
check("Pilot, open Bluetooth", [.openURL("x-apple.systempreferences:com.apple.BluetoothSettings")])
check("Pilot, open Wi-Fi", [.openURL("x-apple.systempreferences:com.apple.wifi-settings-extension")])
check("Pilot, open network settings", [.openURL("x-apple.systempreferences:com.apple.Network-Settings.extension")])
check("Pilot, open Spotlight", [.keys("cmd+space")])   // real miss, 29 Oct: waited 5 s for a Spotlight app
check("Pilot, turn up the volume", [.media("volumeUp")])
check("Pilot, switch back", [.previousApp])
check("Pilot, type hello, how are you", [.type("hello, how are you")])
check("Pilot, search for the best pizza", app: "Google Chrome", [.keys("cmd+l"), .type("the best pizza"), .keys("enter")])
check("Pilot, study mode", [chrome, .keys("cmd+t"), .openApp("Claude"), .keys("cmd+n")])
if case .unmatched(_, let s) = brain.plan("Pilot, open a fresh tab", frontmostApp: "Google Chrome"), s == nil { failures += 1; print("FAIL: expected a suggestion") }
check("Pilot, can you reduce the volume?", [.media("volumeDown")])   // real miss, 28 Oct

// menu items of the current app (rule 8): only after every rule misses, exact titles only
brain.menuItems = { $0 == "Google Chrome" ? [["File", "Export as PDF…"], ["Tab", "Duplicate Tab"], ["View", "Developer", "View Source"],
                                              ["Bookmarks", "Bookmarks & Lists"], ["File", "New Tab"]] : [] }
let dupTab = Action.menu("Google Chrome", ["Tab", "Duplicate Tab"])
check("Pilot, duplicate the tab.", app: "Google Chrome", [dupTab])
check("Pilot, export as PDF", app: "Google Chrome", [.menu("Google Chrome", ["File", "Export as PDF…"])])
check("Pilot, view source", app: "Google Chrome", [.menu("Google Chrome", ["View", "Developer", "View Source"])])
check("Pilot, bookmarks and lists", app: "Google Chrome", [.menu("Google Chrome", ["Bookmarks", "Bookmarks & Lists"])])
check("Pilot, open chrome, duplicate tab", app: "Finder", [chrome, dupTab])          // the app the chain switched to
check("Pilot, new tab", app: "Google Chrome", [.keys("cmd+t")])                      // rules first
check("Pilot, type hello, duplicate tab", app: "Google Chrome", [.type("hello, duplicate tab")])   // rule 7 first
check("Pilot, duplicate", app: "Google Chrome", nil)                                 // no prefixes
check("Pilot, duplicate tab", app: "Finder", nil)                                    // only that app's menus
check("Pilot programs are useful.", app: "Google Chrome", nil)

// click by name (1b): the target is normalised; literal phrases still win
check("Pilot, click Sign in", [.click("sign in")])
check("Pilot, click on the Send button.", [.click("send button")])
check("Pilot, tap Downloads", [.click("downloads")])
check("Pilot, choose English", [.click("english")])
check("Pilot, press play", [.click("play")])
check("Pilot, click send in WhatsApp", [wa, .click("send")])
check("Pilot, click sign in, then scroll down", [.click("sign in"), .scroll("down", 6)])
check("Pilot, press enter", [.keys("enter")])
check("Pilot, press the enter key", [.keys("enter")])
check("Pilot, press escape", [.keys("esc")])
check("Pilot, select all", [.keys("cmd+a")])
check("Pilot, select everything", [.keys("cmd+a")])

// select, copy, cut and delete (31 Oct): keyboard edits work anywhere and chain
let optLeft = Action.keys("opt+shift+left")
check("Pilot, select word", [optLeft])
check("Pilot, select the last word", [optLeft])
check("Pilot, select last 3 words", [optLeft, optLeft, optLeft])
check("Pilot, select the last three words, cut", [optLeft, optLeft, optLeft, .keys("cmd+x")])
check("Pilot, select line", [.keys("cmd+left"), .keys("cmd+shift+right")])
check("Pilot, select to the start of the line", [.keys("cmd+shift+left")])
check("Pilot, select to end of line", [.keys("cmd+shift+right")])
check("Pilot, select paragraph", [.keys("opt+up"), .keys("opt+shift+down")])
check("Pilot, cut", [.keys("cmd+x")])
check("Pilot, cut that", [.keys("cmd+x")])
check("Pilot, cut it", [.keys("cmd+x")])
check("Pilot, copy that", [.keys("cmd+c")])
check("Pilot, copy", [.keys("cmd+c")])
check("Pilot, delete that", [.keys("delete")])
check("Pilot, delete it", [.keys("delete")])
check("Pilot, delete selection", [.keys("delete")])
check("Pilot, delete word", [.keys("opt+delete")])
check("Pilot, delete the last 2 words", [.keys("opt+delete"), .keys("opt+delete")])
check("Pilot, delete line", [.keys("cmd+delete")])
check("Pilot, redo", [.keys("cmd+shift+z")])
check("Pilot, undo", [.keys("cmd+z")])
check("Pilot, paste", [.keys("cmd+v")])
// screenshots (31 Oct): taken as before; "paste the screenshot" pastes the latest, plain "paste" stays your clipboard
check("Pilot, take a screenshot", [.keys("cmd+shift+3")])
check("Pilot, paste the screenshot", [.pasteScreenshot])
check("Pilot, paste my last screenshot", [.pasteScreenshot])
check("Pilot, take a screenshot, paste the screenshot", [.keys("cmd+shift+3"), .pasteScreenshot])
check("Pilot, paste it", [.keys("cmd+v")])
check("Pilot, upload the screenshot", [.uploadScreenshot])
check("Pilot, remove the screenshot", [.click("remove image")])   // the form's × is "Remove image 1"
check("Pilot, delete the screenshot", [.click("remove image")])    // the macro, not "delete {phrase}"
check("Pilot, remove the uploaded image", [.click("remove image")])
check("Pilot, select the screenshot", [.uploadScreenshot])   // not "select {phrase}"
check("Pilot, take a screenshot, click Add images, upload the screenshot", [.keys("cmd+shift+3"), .click("add images"), .uploadScreenshot])
// links: by name like click (a badge number while numbers are up); the page's own address in Chrome
check("Pilot, copy link Docs", [.copyLink("docs")])
check("Pilot, copy the Docs link", [.copyLink("docs")])
check("Pilot, copy link 2", [.copyLink("2")])
check("Pilot, copy link number two", [.copyLink("2")])
let pageLink: [Action] = [.keys("cmd+l"), .keys("cmd+c"), .wait(100), .keys("esc")]
check("Pilot, copy page link", app: "Google Chrome", pageLink)
check("Pilot, copy this link", app: "Google Chrome", pageLink)
check("Pilot, copy the URL", app: "Google Chrome", pageLink)
// a phrase in the focused text field; "select X" outside one is still a click
check("Pilot, select hello world", [.selectText("hello world", op: "select", click: "hello world")])
check("Pilot, select Downloads", [.selectText("Downloads", op: "select", click: "downloads")])
check("Pilot, select 3", [.selectText("3", op: "select", click: "3")])
check("Pilot, delete the quick brown fox", [.selectText("the quick brown fox", op: "delete", click: "quick brown fox")])
check("Pilot, cut see you soon", [.selectText("see you soon", op: "cut", click: "see you soon")])
check("Pilot, copy my address", [.selectText("my address", op: "copy", click: "address")])
check("Pilot, select all", [.keys("cmd+a")])   // still select all

// show numbers (1c): numbers go to click as digits; "close/hide numbers" never touches the Numbers app
check("Pilot, show labels", [.numbers(true)])
check("Pilot, hide numbers", [.numbers(false)])
check("Pilot, close numbers", [.numbers(false)])
check("Pilot, click 12", [.click("12")])
check("Pilot, click twelve", [.click("12")])
check("Pilot, number 7", [.click("7")])
check("Pilot, click number twenty-one", [.click("21")])
check("Pilot, click a hundred and five", [.click("105")])
check("Pilot, click #3.", [.click("3")])
check("Pilot, show numbers, click 4", [.numbers(true), .click("4")])
// a tie numbers just the tied matches (30 Oct); Hands reads these while badges are up
check("Pilot, click the second one", [.click("second one")])
check("Pilot, click the last one", [.click("last one")])
check("Pilot, click the first one.", [.click("first one")])

// no hands: wake word on/off, dictation
check("Pilot, start listening.", [.listen(true)])
check("Pilot, stop listening", [.listen(false)])
check("start listening", trigger: false, [.listen(true)])
check("Pilot, dictate", [.dictate])
check("Dictate.", trigger: false, [.dictate])
check("Pilot, start dictation", [.dictate])
// Wispr's text without punctuation
check("Pilot scroll right across space", [.keys("ctrl+right")])
check("Pilot dictate", [.dictate])
check("Pilot open Chrome then new tab", [chrome, .keys("cmd+t")])
check("Pilot open Chrome new tab", [chrome, .keys("cmd+t")])

// teaching (rule 1b): parsed before chain splitting; taught phrases then match like macros
func expect(_ text: String, _ plan: Plan, line: Int = #line) {
    let got = brain.plan(text, frontmostApp: nil)
    if got != plan { failures += 1; print("FAIL line \(line): \"\(text)\"\n  got:      \(got)\n  expected: \(plan)") }
}
expect("Pilot, when I say focus time, do open Notion, mute.", .teach(phrase: "focus time", commands: ["open Notion", "mute"]))
expect("Pilot, when I say \"good night,\" run lock screen", .teach(phrase: "good night", commands: ["lock screen"]))
expect("Pilot, when I say do not disturb, do mute", .teach(phrase: "do not disturb", commands: ["mute"]))
expect("Pilot, teach that: new tab", .teach(phrase: nil, commands: ["new tab"]))
expect("Pilot, that means open a new tab, then scroll down.", .teach(phrase: nil, commands: ["open a new tab", "scroll down"]))
expect("Pilot, forget focus time.", .forget("focus time"))
var taughtConfig = brain.config
taughtConfig.macros["focus time"] = ["mute", "full screen"]
let taughtBrain = Brain(config: taughtConfig, installedApps: ["Time Machine"])
check("Pilot, focus time", [.openApp("Time Machine")])   // "focus" = "switch to", "time" = unique prefix (typo pass)
if case .unmatched = brain.plan("focus time", frontmostApp: nil, requireTrigger: false, typos: false) {} else {
    failures += 1; print("FAIL: without typos, \"focus time\" should be free to teach")
}
if case .run(let s) = taughtBrain.plan("Pilot, focus time.", frontmostApp: nil), s.flatMap(\.actions) == [.media("mute"), .keys("ctrl+cmd+f")] {} else {
    failures += 1; print("FAIL: taught phrase didn't run like a macro")
}

// open anything by name (3): needs a file/folder word; known folders from any app; Settings panes
let downloads = Action.openFile("/Users/me/Downloads", folder: true, reveal: false)
check("Pilot, open downloads", app: "Google Chrome", [downloads])
check("Pilot, open the downloads folder", [downloads])
check("Pilot, open downloads", app: "Finder", [.keys("cmd+opt+l")])   // Finder's own command wins in Finder
check("Pilot, open home folder", [.openFile("/Users/me", folder: true, reveal: false)])
check("Pilot, open file my resume", [.openFile("resume", folder: false, reveal: false)])
check("Pilot, open the hackathon folder", [.openFile("hackathon", folder: true, reveal: false)])
check("Pilot, show resume.pdf in Finder", [.openFile("resume.pdf", folder: false, reveal: true)])
check("Pilot, find file budget 2026", [.openFile("budget 2026", folder: false, reveal: false)])
check("Pilot, open file report", app: "Visual Studio Code", [.keys("cmd+p"), .wait(200), .type("report")])   // VS Code's quick open there
check("Pilot, open resume", nil)   // no file word: never a file search
check("Pilot, open bluetooth settings", [.openURL("x-apple.systempreferences:com.apple.BluetoothSettings")])
check("Pilot, Wi-Fi settings.", [.openURL("x-apple.systempreferences:com.apple.wifi-settings-extension")])
check("Pilot, open privacy and security settings", [.openURL("x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension")])
check("Pilot, open settings", [.openApp("System Settings")])

// selected text (4): "this" is a filler, so free text needs a real word; {selection} is filled in at run time
let searchSel = Action.openURL("https://www.google.com/search?q={selection}")
let askSel: [Action] = [.openApp("Claude"), .keys("cmd+n"), .wait(600), .type("{selection}"), .wait(100), .keys("enter")]
check("Pilot, search this", [searchSel])
check("Pilot, search this.", app: "Google Chrome", [searchSel])   // not Chrome's own "search for {query}"
check("Pilot, google this", app: "Visual Studio Code", [searchSel])
check("Pilot, translate this", [.openURL("https://translate.google.com/?sl=auto&tl=en&text={selection}&op=translate")])
check("Pilot, define this", [.openURL("dict://{selection}")])
check("Pilot, what does this mean?", [.openURL("dict://{selection}")])
check("Pilot, ask Claude about this", askSel)
check("Pilot, ask Claude about this", app: "Claude", askSel)   // not Claude's own "ask {query}"
check("Pilot, ask Claude about black holes", [.openApp("Claude"), .keys("cmd+n"), .wait(600), .type("black holes"), .wait(100), .keys("enter")])
check("Pilot, search for this week's news", app: "Google Chrome", [.keys("cmd+l"), .type("this week's news"), .keys("enter")])
check("Pilot, type the", nil)   // free text needs one real word

// wake word (30 Oct): only Wispr's text runs, never Apple's words; a leading "Pilot" Wispr caught is dropped
func woke(_ wispr: String) -> String { brain.wakeCommand(wispr) }
check(woke("Open Chrome, new tab, search for Docker networking."), trigger: false, [chrome, .keys("cmd+t"), .keys("cmd+l"), .type("Docker networking"), .keys("enter")])
check(woke("Pilot, open Chrome."), trigger: false, [chrome])
check(woke("pilot open chrome"), trigger: false, [chrome])
check(woke("Scroll right across space."), trigger: false, [.keys("ctrl+right")])
check(woke("Dictate."), trigger: false, [.dictate])
check(woke("Rome."), trigger: false, nil)   // Wispr caught only a scrap: nothing runs (Pilot's own words never fill it in)
if woke("Pilots are great") != "Pilots are great" { failures += 1; print("FAIL: \"Pilots\" isn't the name") }

// training sentences for the speech recognizer: slots filled, no braces left
let training = brain.trainingPhrases()
for t in ["open chrome", "scroll right across space", "click 12", "pause video", "study mode", "switch to College profile"] where !training.contains(t) {
    failures += 1; print("FAIL: training sentences lack \"\(t)\"")
}
if training.contains(where: { $0.contains("{") }) { failures += 1; print("FAIL: a training sentence still has a slot") }
print("training sentences: \(training.count)")

// speed: the brain must be far under 100 ms
let t0 = Date()
for _ in 0..<100 { _ = brain.plan("Pilot, can you open a new Chrome tab, search for Docker networking.", frontmostApp: "Finder") }
let ms = Date().timeIntervalSince(t0) * 1000 / 100
print(String(format: "avg plan time: %.2f ms", ms))
if ms > 15 { failures += 1; print("FAIL: plan too slow") }

print(failures == 0 ? "All brain checks passed" : "\(failures) failure(s)")
exit(failures == 0 ? 0 : 1)
