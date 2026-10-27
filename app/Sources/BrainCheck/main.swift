// Self-check for the Brain against the real commands.json: `swift run --package-path app BrainCheck`
import Foundation
import PilotBrain

let path = CommandLine.arguments.dropFirst().first ?? "../commands/commands.json"
let brain = try Brain(json: Data(contentsOf: URL(fileURLWithPath: path)),
                      installedApps: ["Google Chrome", "Claude", "Visual Studio Code", "Finder", "Telegram", "WhatsApp", "Safari", "Terminal"])
var failures = 0

func actions(_ text: String, app: String? = nil, trigger: Bool = true) -> [Action]? {
    if case .run(let steps) = brain.plan(text, frontmostApp: app, requireTrigger: trigger) { return steps.flatMap(\.actions) }
    return nil
}
func check(_ text: String, app: String? = nil, trigger: Bool = true, _ expected: [Action]?, line: Int = #line) {
    let got = actions(text, app: app, trigger: trigger)
    if got != expected { failures += 1; print("FAIL line \(line): \"\(text)\" [\(app ?? "-")]\n  got:      \(String(describing: got))\n  expected: \(String(describing: expected))") }
}

// trigger handling: punctuation, case, "hey", no trigger
check("Pilot, open Chrome.", [.openApp("Google Chrome")])
check("pilot open chrome", [.openApp("Google Chrome")])
check("  Hey, Pilot: launch Visual Studio Code!", [.openApp("Visual Studio Code")])
check("Open Chrome.", nil)
if brain.plan("Open Chrome.", frontmostApp: nil) != .notForPilot { failures += 1; print("FAIL: non-Pilot text should be notForPilot") }
check("Pilots are great", nil)
check("open chrome", trigger: false, [.openApp("Google Chrome")])

// fuzzy app names, strict quit
check("Pilot, switch to telegrm", [.openApp("Telegram")])
check("Pilot, open VS Code", [.openApp("Visual Studio Code")])
check("Pilot, quit chrome", [.quitApp("Google Chrome")])
check("Pilot, quit chrom", nil)

// chains
check("Pilot, open Chrome, new tab, search for Docker networking.",
      [.openApp("Google Chrome"), .keys("cmd+t"), .keys("cmd+l"), .type("Docker networking"), .keys("enter")])
check("Pilot open chrome then new tab and then scroll down", [.openApp("Google Chrome"), .keys("cmd+t"), .scroll("down")])
check("Pilot, open chrome and new tab", [.openApp("Google Chrome"), .keys("cmd+t")])
check("Pilot, search for salt and pepper", app: "Google Chrome", [.keys("cmd+l"), .type("salt and pepper"), .keys("enter")])
check("Pilot, open chrome, blorp, new tab", nil)

// per-app commands, "in <app>", filler words
check("Pilot, toggle the sidebar", app: "Visual Studio Code", [.keys("cmd+b")])
check("Pilot, toggle sidebar", app: "Finder", [.keys("ctrl+cmd+s")])
check("Pilot, open the sidebar in Claude", [.openApp("Claude"), .keys("cmd+b")])
check("Pilot, um, can you please open a new tab", app: "Google Chrome", [.keys("cmd+t")])
check("Pilot, toggle sidebar", app: "Google Chrome", [.notConfigured("Chrome has no fixed side panel shortcut; set one in chrome://extensions/shortcuts or pick a panel")])
check("Pilot, search for docker", app: "Terminal", [.openApp("Google Chrome"), .keys("cmd+t"), .type("docker"), .keys("enter")])
check("Pilot, google rust lifetimes", app: "Google Chrome", [.keys("cmd+l"), .type("rust lifetimes"), .keys("enter")])

// free text keeps its words and absorbs trailing segments
check("Pilot, type hello, how are you", [.type("hello, how are you")])
check("Pilot, search for the best pizza", app: "Google Chrome", [.keys("cmd+l"), .type("the best pizza"), .keys("enter")])

// macros
check("Pilot, study mode", [.openApp("Google Chrome"), .keys("cmd+t"), .openApp("Claude"), .keys("cmd+n")])

// speed: the brain must be far under 100 ms
let t0 = Date()
for _ in 0..<100 { _ = brain.plan("Pilot, open Chrome, new tab, search for Docker networking.", frontmostApp: nil) }
let ms = Date().timeIntervalSince(t0) * 1000 / 100
print(String(format: "avg plan time: %.2f ms", ms))
if ms > 20 { failures += 1; print("FAIL: plan too slow") }

print(failures == 0 ? "All brain checks passed" : "\(failures) failure(s)")
exit(failures == 0 ? 0 : 1)
