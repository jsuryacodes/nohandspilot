// Self-check for the Brain against the real commands.json: `swift run --package-path app BrainCheck`
import Foundation
import PilotBrain

let path = CommandLine.arguments.dropFirst().first ?? "../commands/commands.json"
let profiles: [(key: String, value: String)] = [("Jaya", "Default"), ("College", "Profile 1"), ("Jaya Surya", "Profile 2"), ("Work", "Profile 9"),
                                                ("Jaya Surya", "Default"), ("PENUMATCHA JAYA SURYA", "Profile 1"), ("Jaya Surya Penumatcha", "Profile 2")]
let brain = try Brain(json: Data(contentsOf: URL(fileURLWithPath: path)),
                      installedApps: ["Google Chrome", "Claude", "Visual Studio Code", "Finder", "Telegram", "WhatsApp", "Safari", "Terminal",
                                      "GitHub Desktop", "YouTube", "ChatGPT", "Spotify"],
                      slotValues: ["profile": profiles])
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

// misc
check("Pilot, pause the music", [.media("play")])
check("Pilot, turn up the volume", [.media("volumeUp")])
check("Pilot, switch back", [.previousApp])
check("Pilot, type hello, how are you", [.type("hello, how are you")])
check("Pilot, search for the best pizza", app: "Google Chrome", [.keys("cmd+l"), .type("the best pizza"), .keys("enter")])
check("Pilot, study mode", [chrome, .keys("cmd+t"), .openApp("Claude"), .keys("cmd+n")])
if case .unmatched(_, let s) = brain.plan("Pilot, open a fresh tab", frontmostApp: "Google Chrome"), s == nil { failures += 1; print("FAIL: expected a suggestion") }

// speed: the brain must be far under 100 ms
let t0 = Date()
for _ in 0..<100 { _ = brain.plan("Pilot, can you open a new Chrome tab, search for Docker networking.", frontmostApp: "Finder") }
let ms = Date().timeIntervalSince(t0) * 1000 / 100
print(String(format: "avg plan time: %.2f ms", ms))
if ms > 15 { failures += 1; print("FAIL: plan too slow") }

print(failures == 0 ? "All brain checks passed" : "\(failures) failure(s)")
exit(failures == 0 ? 0 : 1)
