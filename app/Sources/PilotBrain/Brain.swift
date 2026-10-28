// Brain: text in, plan out. Foundation only, no macOS APIs, so a Windows "Hands" can reuse it.
//
// Matching rules (keep the web version identical):
//  1. Trigger: text must start with a trigger word ("pilot", "hey pilot", ...), ignoring case and
//     punctuation. The command bar passes requireTrigger=false.
// 1b. Teaching, checked before splitting so its commas stay inside: "when I say X, do A, B" makes X run
//     A then B; "teach that: A" / "that means A" makes the last missed segment run A; "forget X".
//     The app refuses a phrase that already does something (typo-tolerant app names don't count:
//     "focus time" may reach Time Machine by prefix, yet a taught phrase wins over that anyway) and
//     commands that don't plan right now.
//     Taught phrases are stored in learned.json (same shape as macros) and match like macros (6a).
//  2. Chain split on , ; . ! ? and the words "then" / "and then". A segment that doesn't match and
//     contains "and" is retried as two commands split on "and".
//  3. Words are lowercased, punctuation dropped, synonyms replaced (longest first) and filler words
//     skipped. Phrases go through the same steps, so "Can you open the new tab?" == "open new tab".
//  4. Command words must match exactly. Slots:
//       {app}  app name: alias or exact installed name (typos allowed only in step 6e)
//       {site} a key of "sites"            {url}  something like docker.com
//       {n}    1–9, "three", "third", "last"
//       a slot with runtime values (e.g. {profile} = Chrome profiles, {folder} = Downloads, Documents,
//              Desktop, home, Applications): exact, then unique prefix
//       anything else ({query}, {text}) = free text kept as spoken; it needs one non-filler word, so
//              "search this" isn't a search for "this" (it's the selected-text command)
//       {selection} in an action template is no slot: Hands fills in the selected text when the run
//              starts (URL-encoded in URLs)
//       click's {target} is free text normalised as in rule 3. Hands then picks the visible element
//       whose normalised name equals it, else starts with it, else contains all its words (window
//       before menu items, controls before plain text). A tie is refused, never guessed.
//  5. Commands scoped to the current app are tried first, then global ones; more literal words wins,
//     then JSON order. The current app follows the chain: after "open chrome", Chrome commands apply.
//     Once the chain itself has switched app ("open music and search florida"), later commands
//     prefer ones that stay in that app (Music search, not a Chrome web search).
//  6. Per segment, first hit wins:
//       a. macro name
//       b. exact match (free text may not end in "in/on <app or site>")
//       c. "<command> in/on <app>"               → switch to the app, run its command there
//       d. app named anywhere ("new Chrome tab") → drop the name, run the rest in that app
//          (c and d only accept commands that stay in that app: "search X in WhatsApp" never opens Chrome)
//       e. exact match again, now allowing typos in app names
//  7. A segment that doesn't match right after a free-text command is appended to its text
//     ("type hello, how are you" types "hello, how are you").
//  8. Otherwise it may name a menu item of the current app ("duplicate tab", "export as PDF"): the
//     item's title, normalised as in rule 3 ("…" and "&" too), must equal the segment exactly. Only
//     enabled items count, never the Apple menu. Menus are read only on this miss path.
//  9. If any segment still doesn't match, nothing runs.
import Foundation

public struct Config: Codable {
    public var triggerWords: [String]
    public var fillerWords: [String]
    public var synonyms: [String: String]
    public var apps: [String: String]
    public var browser: String?
    public var sites: [String: Site]?
    public var hotkey: String?
    public var commands: [Command]
    public var macros: [String: [String]]
}

public struct Site: Codable { public var url: String; public var search: String? }

public struct Command: Codable {
    public var id: String
    public var app: String?
    public var phrases: [String]
    public var action: ActionSpec
    public var say: String?
}

public struct ActionSpec: Codable {
    public var type: String   // openApp quitApp hideApp previousApp openURL chromeProfile keys type sequence scroll media help click
    public var keys: String?
    public var text: String?
    public var url: String?
    public var key: String?
    public var steps: [String]?
    public var direction: String?
    public var amount: Int?
    public var note: String?
    public var folder: Bool?   // openFile: folders only
    public var reveal: Bool?   // openFile: show in Finder instead of opening
}

public enum Action: Equatable {
    case openApp(String), quitApp(String), hideApp(String), previousApp, openURL(String), chromeProfile(String)
    case keys(String), type(String), scroll(String, Int), media(String), wait(Int), help
    case menu(String, [String])   // app, title path: ("Google Chrome", ["Tab", "Duplicate Tab"])
    case click(String)            // a visible element by name, normalised as in rule 3, or a badge number ("12")
    case numbers(Bool)            // show / hide numbered badges on everything clickable
    case openFile(String, folder: Bool, reveal: Bool)   // a name to search for, or a known folder's path
    case listen(Bool)             // wake word on / off: hearing "Pilot" starts the dictation app hands-free
    case dictate                  // start hands-free dictation; the text is typed, not run
    case notConfigured(String)
}

public struct Step: Equatable {
    public var id: String
    public var say: String
    public var actions: [Action]
    var slots: [String: String] = [:]
    var freeKey: String? = nil       // slot holding free text, for rule 7
}

public enum Plan: Equatable {
    case notForPilot                         // no trigger word: leave the text alone
    case run([Step])
    case unmatched(String, suggestion: String?)
    case teach(phrase: String?, commands: [String])   // rule 1b; phrase nil = "teach that" (the last miss)
    case forget(String)
}

public final class Brain {
    public let config: Config
    let installedApps: [String]
    /// Other names apps go by, e.g. ["OBS Studio": "OBS"] (display name → .app file name).
    let appAliases: [String: String]
    /// Runtime slot values, e.g. ["profile": [("Jaya Surya", "Profile 2"), ...]]. Earlier entries win ties.
    let slotValues: [String: [(key: String, value: String)]]
    /// Title paths of a running app's enabled menu items, e.g. [["File", "Export as PDF…"]] (rule 8).
    public var menuItems: ((_ app: String) -> [[String]])?
    private var compiled: [(cmd: Command, pattern: [Tok], literals: Int)] = []
    private let synonyms: [([String], [String])]
    private let fillers: [[String]]
    private let triggerRegex: NSRegularExpression
    private var appCache: [String: String?] = [:]
    private static let builtinSlots: Set<String> = ["app", "site", "n", "url"]

    public init(config: Config, installedApps: [String] = [], appAliases: [String: String] = [:], slotValues: [String: [(key: String, value: String)]] = [:]) {
        self.config = config
        self.installedApps = installedApps
        self.appAliases = appAliases
        self.slotValues = slotValues
        func words(_ s: String) -> [String] {
            s.split(whereSeparator: { $0.isWhitespace }).map { String($0).lowercased().filter { $0.isLetter || $0.isNumber || $0 == "`" } }.filter { !$0.isEmpty }
        }
        synonyms = config.synonyms.map { (words($0.key), words($0.value)) }.sorted { $0.0.count > $1.0.count }
        fillers = config.fillerWords.map(words).filter { !$0.isEmpty }.sorted { $0.count > $1.count }
        let triggers = config.triggerWords.sorted { $0.count > $1.count }
            .map { $0.split(separator: " ").map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: "[\\s,.!:]+") }
        triggerRegex = try! NSRegularExpression(pattern: "^[\\s\"'“]*(?:\(triggers.joined(separator: "|")))\\b[\\s,.!:;-]*", options: .caseInsensitive)
        for cmd in config.commands {
            for phrase in cmd.phrases {
                let pattern = canon(tokenize(phrase)).filter { !$0.filler }
                compiled.append((cmd, pattern, pattern.filter { !$0.isSlot }.count))
            }
        }
        compiled.sort { $0.literals > $1.literals }   // stable: JSON order breaks ties
    }

    public convenience init(json: Data, installedApps: [String] = [], appAliases: [String: String] = [:], slotValues: [String: [(key: String, value: String)]] = [:]) throws {
        self.init(config: try JSONDecoder().decode(Config.self, from: json), installedApps: installedApps, appAliases: appAliases, slotValues: slotValues)
    }

    /// Text after the trigger word, or nil if the text isn't addressed to Pilot.
    public func stripTrigger(_ text: String) -> String? {
        let ns = text as NSString
        guard let m = triggerRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(from: m.range.upperBound)
    }

    private var typos = true

    /// `typos: false` skips typo-tolerant app names (step 6e), e.g. to ask whether a phrase is already taken.
    public func plan(_ text: String, frontmostApp: String?, requireTrigger: Bool = true, typos: Bool = true) -> Plan {
        self.typos = typos
        defer { self.typos = true }
        var body = text
        if let rest = stripTrigger(text) { body = rest } else if requireTrigger { return .notForPilot }
        if let teaching = teaching(body) { return teaching }
        switch planChain(body, app: frontmostApp, explicit: false, depth: 0) {
        case .success(let steps):
            return steps.isEmpty ? .unmatched(body.trimmingCharacters(in: .whitespaces), suggestion: nil) : .run(steps)
        case .failure(let miss):
            return .unmatched(miss.segment, suggestion: suggest(miss.segment, app: miss.app))
        }
    }

    /// Wake word: Apple's recognizer heard `said` after "Pilot", the first `missed` words before Wispr's mic was on,
    /// and Wispr then typed `wispr`. Returns the command: those first words joined to Wispr's text, else Apple's words
    /// alone. Wispr's first word may repeat the last of them (Wispr's copy stays) or be the end of a word it half
    /// heard ("Rome" for "chrome", "Cross" for "across"; Apple's whole word stays).
    public func joinWake(said: [String], missed: Int, wispr: String, frontmostApp: String?) -> String {
        let heard = wispr.split(separator: " ").map(String.init), start = Array(said.prefix(missed)), next = said.dropFirst(missed).prefix(1)
        func letters(_ w: String?) -> String { (w ?? "").lowercased().filter(\.isLetter) }
        let first = letters(heard.first), last = letters(start.last), upcoming = letters(next.first)
        var join = start + heard
        if !first.isEmpty, first != upcoming {
            if first == last { join = start.dropLast() + heard }
            else if upcoming.hasSuffix(first) { join = start + next + heard.dropFirst() }
            else if last.hasSuffix(first) { join = start + heard.dropFirst() }
        }
        let texts = [join, start + heard, said].map { $0.joined(separator: " ") }.filter { !$0.isEmpty }
        return texts.first { if case .unmatched = plan($0, frontmostApp: frontmostApp, requireTrigger: false) { return false }; return true } ?? texts.first ?? wispr
    }

    /// Rule 1b, on the raw text so commas stay inside: "when I say X, do A, B", "teach that: A", "that means A", "forget X".
    private func teaching(_ body: String) -> Plan? {
        let s = body.trimmingCharacters(in: .whitespacesAndNewlines)
        func groups(_ pattern: String) -> [String]? {
            guard let m = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive).firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
            return (1..<m.numberOfRanges).map { String(s[Range(m.range(at: $0), in: s)!]) }
        }
        func clean(_ t: String) -> String { t.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”'‘’.,:;!?").union(.whitespaces)) }
        func commands(_ t: String) -> [String] { segments(t).filter { !key(canon(tokenize($0))).isEmpty } }
        if let g = groups(#"^when i say\s+(.+?)[\s,]*\b(?:do|run)\b[\s:,]*(.+)$"#) { return .teach(phrase: clean(g[0]), commands: commands(g[1])) }
        if let g = groups(#"^(?:teach that|that means)\b[\s:,-]*(.+)$"#) { return .teach(phrase: nil, commands: commands(g[0])) }
        if let g = groups(#"^forget\s+(.+)$"#) { return .forget(clean(g[0])) }
        return nil
    }

    // MARK: chain

    struct Miss: Error { var segment: String; var app: String? }

    /// `explicit`: the current app was chosen by this chain (not just whatever happened to be in front).
    /// Rule 2's split, without the "and" retry.
    func segments(_ text: String) -> [String] {
        text.replacingOccurrences(of: "(?i)[,;!?]+|\\.(?=\\s|$)|\\band then\\b|\\bthen\\b", with: "\u{1}", options: .regularExpression)
            .split(separator: "\u{1}").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func planChain(_ text: String, app: String?, explicit: Bool, depth: Int) -> Result<[Step], Miss> {
        let segments = self.segments(text)
        var steps: [Step] = []
        var app = app, explicit = explicit
        func lastFree() -> Int? { steps.last?.freeKey != nil ? steps.count - 1 : nil }
        var freeIndex: Int?
        for seg in segments where !key(canon(tokenize(seg))).isEmpty {   // skip "um,"
            if let s = planSegment(seg, app: &app, explicit: &explicit, depth: depth) {
                steps += s
                freeIndex = lastFree()
                continue
            }
            if seg.range(of: "\\band\\b", options: [.regularExpression, .caseInsensitive]) != nil {
                let parts = seg.components(separatedBy: " and ").map { $0.trimmingCharacters(in: .whitespaces) }
                var tmpApp = app, tmpExplicit = explicit, sub: [Step] = [], ok = !parts.contains("")
                for p in parts where ok { if let s = planSegment(p, app: &tmpApp, explicit: &tmpExplicit, depth: depth) { sub += s } else { ok = false } }
                if ok { steps += sub; app = tmpApp; explicit = tmpExplicit; freeIndex = lastFree(); continue }
            }
            if let i = freeIndex, let freeKey = steps[i].freeKey, let cmd = config.commands.first(where: { $0.id == steps[i].id }) {   // rule 7
                var slots = steps[i].slots
                slots[freeKey, default: ""] += ", " + seg
                let lead = Array(steps[i].actions.prefix { if case .openApp = $0 { return true } else { return false } })
                var merged = makeStep(cmd, slots: slots)
                if case .openApp? = merged.actions.first {} else { merged.actions.insert(contentsOf: lead, at: 0) }
                steps[i] = merged
                continue
            }
            let said = key(canon(tokenize(seg)))   // rule 8
            if let a = app, let path = menuItems?(a).first(where: { normalize($0.last ?? "") == said }) {
                steps.append(Step(id: "menu", say: path.joined(separator: " › "), actions: [.menu(a, path)]))
                freeIndex = nil
                continue
            }
            return .failure(Miss(segment: seg, app: app))
        }
        return .success(steps)
    }

    private func planSegment(_ seg: String, app: inout String?, explicit: inout Bool, depth: Int) -> [Step]? {
        let toks = canon(tokenize(seg))
        // a. macro
        if depth < 3, let macro = config.macros.first(where: { key(canon(tokenize($0.key))) == key(toks) }) {
            var out: [Step] = []
            for line in macro.value {
                guard case .success(let s) = planChain(line, app: app, explicit: explicit, depth: depth + 1) else { return nil }
                for step in s { if let a = contextApp(after: step) { app = a; explicit = true } }
                out += s
            }
            return out
        }
        var current = app, currentExplicit = explicit
        defer { app = current; explicit = currentExplicit }
        func done(_ step: Step) -> [Step] {
            if let a = contextApp(after: step) { current = a; currentExplicit = true }
            return [step]
        }
        // b. exact; inside an app the chain switched to, prefer commands that stay there (rule 5)
        if explicit, let a = app, let step = match(toks, app: a, fuzzy: false, accept: { self.stays($0, in: a) }) { return done(step) }
        if let step = match(toks, app: app, fuzzy: false) { return done(step) }
        // c. "... in chrome"
        let words = seg.split(separator: " ").map(String.init)
        if let i = words.lastIndex(where: { ["in", "on"].contains($0.lowercased()) }), i > 0, i < words.count - 1,
           let target = resolveApp(words[(i + 1)...].joined(separator: " "), fuzzy: typos),
           let step = match(canon(tokenize(words[..<i].joined(separator: " "))), app: target, fuzzy: false, accept: { self.stays($0, in: target) }) {
            return done(inApp(step, target))
        }
        // d. app named anywhere: "open a new chrome tab", "close the claude sidebar"
        if words.count > 1 {
            for len in stride(from: min(3, words.count - 1), through: 1, by: -1) {
                for start in 0...(words.count - len) {
                    guard let target = resolveApp(words[start..<start + len].joined(separator: " "), fuzzy: false) else { continue }
                    var rest = words
                    rest.removeSubrange(start..<start + len)
                    if start > 0, ["in", "on", "using", "with", "from", "of", "inside"].contains(rest[start - 1].lowercased()) { rest.remove(at: start - 1) }
                    if let step = match(canon(tokenize(rest.joined(separator: " "))), app: target, fuzzy: false, accept: { self.stays($0, in: target) }) {
                        return done(inApp(step, target))
                    }
                }
            }
        }
        // e. exact, allowing typos in app names
        if typos, let step = match(toks, app: app, fuzzy: true) { return done(step) }
        return nil
    }

    /// A command aimed at an app ("search X in WhatsApp") must not switch to a different app (Chrome).
    private func stays(_ step: Step, in target: String) -> Bool {
        let browser = config.browser ?? "Google Chrome"
        for a in step.actions {
            switch a {
            case .openApp(let name) where name != target: return false
            case .openURL, .chromeProfile: if target != browser { return false }
            default: break
            }
        }
        return true
    }

    /// Make sure the step runs in `target`: switch to it first unless the step already does.
    private func inApp(_ step: Step, _ target: String) -> Step {
        var step = step
        switch step.actions.first {
        case .openApp?, .quitApp?, .hideApp?, .openURL?, .chromeProfile?: break
        default: step.actions.insert(.openApp(target), at: 0)
        }
        return step
    }

    /// Which app is in front after this step, for scoping the next command in a chain.
    private func contextApp(after step: Step) -> String? {
        var app: String?
        for a in step.actions {
            switch a {
            case .openApp(let name): app = name
            case .openURL(let url): if url.hasPrefix("http") { app = config.browser ?? "Google Chrome" }   // not Settings or dict: links
            case .chromeProfile: app = config.browser ?? "Google Chrome"
            default: break
            }
        }
        return app
    }

    // MARK: matching

    private func match(_ toks: [Tok], app: String?, fuzzy: Bool, accept: (Step) -> Bool = { _ in true }) -> Step? {
        let scoped = compiled.lazy.filter { $0.cmd.app != nil && $0.cmd.app == app }
        let global = compiled.lazy.filter { $0.cmd.app == nil }
        for c in [Array(scoped), Array(global)].joined() {
            if let slots = bind(c.pattern, toks, fuzzy: fuzzy && c.cmd.action.type != "quitApp") {
                let step = makeStep(c.cmd, slots: slots)
                if accept(step) { return step }
            }
        }
        return nil
    }

    private func isFree(_ slot: String) -> Bool { !Brain.builtinSlots.contains(slot) && slotValues[slot] == nil }

    /// Slot values if the pattern matches the whole token list, else nil.
    private func bind(_ pattern: [Tok], _ toks: [Tok], fuzzy: Bool) -> [String: String]? {
        func go(_ pi: Int, _ ti: Int, _ acc: [String: String]) -> [String: String]? {
            var ti = ti
            if pi == pattern.count {
                while ti < toks.count, toks[ti].filler { ti += 1 }
                return ti == toks.count ? acc : nil
            }
            let p = pattern[pi]
            if !p.isSlot {
                while ti < toks.count, toks[ti].filler { ti += 1 }
                guard ti < toks.count, toks[ti].norm == p.norm else { return nil }
                return go(pi + 1, ti + 1, acc)
            }
            let name = String(p.norm.dropFirst().dropLast())
            if !isFree(name) { while ti < toks.count, toks[ti].filler { ti += 1 } }   // "open the youtube"
            for end in stride(from: toks.count, to: ti, by: -1) {   // longest span first
                if isFree(name), !toks[ti..<end].contains(where: { !$0.filler }) { continue }   // "search this": no text, only a filler
                let raw = toks[ti..<end].map(\.raw).filter { !$0.isEmpty }.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                guard !raw.isEmpty, let value = resolveSlot(name, raw, fuzzy: fuzzy) else { continue }
                var next = acc; next[name] = value
                if let r = go(pi + 1, end, next) { return r }
            }
            return nil
        }
        return go(0, 0, [:])
    }

    private func resolveSlot(_ name: String, _ raw: String, fuzzy: Bool) -> String? {
        switch name {
        case "app": return resolveApp(raw, fuzzy: fuzzy)
        case "site": return config.sites?.keys.first { compact($0) == compact(raw) }
        case "n": return number(raw)
        case "url":
            let r = raw.trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
            return r.range(of: "^[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)+(/\\S*)?$", options: .regularExpression) != nil ? r : nil
        default:
            if let values = slotValues[name] { return resolveNamed(raw, values, fuzzy: fuzzy) }
            // free text mustn't swallow a trailing "in chrome" / "on youtube" (rule 6b)
            if !fuzzy, let r = raw.range(of: "\\s(in|on)\\s+(.+)$", options: [.regularExpression, .caseInsensitive]) {
                let tail = raw[r].split(separator: " ").dropFirst().joined(separator: " ")
                if resolveApp(tail, fuzzy: false) != nil || resolveSlot("site", tail, fuzzy: false) != nil { return nil }
            }
            return raw
        }
    }

    private func number(_ raw: String) -> String? {
        let words = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9,
                     "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5, "sixth": 6, "seventh": 7, "eighth": 8, "ninth": 9,
                     "1st": 1, "2nd": 2, "3rd": 3, "4th": 4, "5th": 5, "6th": 6, "7th": 7, "8th": 8, "9th": 9, "last": 9]
        let w = raw.lowercased().trimmingCharacters(in: .punctuationCharacters)
        if let n = Int(w), (1...9).contains(n) { return String(n) }
        return words[w].map(String.init)
    }

    /// Badge numbers for click: "12", "twelve", "twenty one", "a hundred and five" (normalised text).
    private func spokenNumber(_ t: String) -> Int? {
        let units = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve",
                     "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
        let tens = ["twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
        let words = t.split(separator: " ").map(String.init).filter { $0 != "and" }
        if words.count == 1, let n = Int(words[0]) { return n }
        var n = 0
        for w in words {
            if let u = units.firstIndex(of: w) { n += u }
            else if let d = tens.firstIndex(of: w) { n += (d + 2) * 10 }
            else if w == "hundred" { n = max(n, 1) * 100 }
            else { return nil }
        }
        return words.isEmpty ? nil : n
    }

    /// Exact (earlier entries win), then unique prefix, then (fuzzy pass) 1–2 typos.
    private func resolveNamed(_ raw: String, _ values: [(key: String, value: String)], fuzzy: Bool) -> String? {
        let s = compact(raw)
        guard !s.isEmpty else { return nil }
        if let hit = values.first(where: { compact($0.key) == s }) { return hit.value }
        let prefixed = Set(values.filter { compact($0.key).hasPrefix(s) }.map(\.value))
        if prefixed.count == 1, s.count >= 3 { return prefixed.first }
        guard fuzzy else { return nil }
        let close = values.filter { levenshtein(compact($0.key), s) <= (s.count >= 8 ? 2 : 1) }
        return Set(close.map(\.value)).count == 1 ? close[0].value : nil
    }

    private func makeStep(_ cmd: Command, slots: [String: String]) -> Step {
        func fill(_ s: String, encode: Bool = false) -> String {
            var s = s
            for (k, v) in slots {
                let value = encode ? (v.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? v) : v
                s = s.replacingOccurrences(of: "{\(k)}", with: value)
            }
            return s
        }
        let a = cmd.action
        var actions: [Action] = []
        switch a.type {
        case "openApp": actions = [.openApp(slots["app"] ?? cmd.app ?? "")]
        case "quitApp": actions = [.quitApp(slots["app"] ?? "")]
        case "hideApp": actions = [.hideApp(slots["app"] ?? cmd.app ?? "")]
        case "previousApp": actions = [.previousApp]
        case "chromeProfile": actions = [.chromeProfile(slots["profile"] ?? "")]
        case "help": actions = [.help]
        case "click":
            let raw = slots["target"] ?? ""
            actions = [.click(spokenNumber(normalize(raw.replacingOccurrences(of: "-", with: " "))).map(String.init) ?? normalize(raw))]
        case "showNumbers", "hideNumbers": actions = [.numbers(a.type == "showNumbers")]
        case "startListening", "stopListening": actions = [.listen(a.type == "startListening")]
        case "dictate": actions = [.dictate]
        case "openFile":
            var name = canon(tokenize(slots["query"] ?? ""))   // "my resume" → "resume"
            while name.first?.filler == true { name.removeFirst() }
            while name.last?.filler == true { name.removeLast() }
            actions = [.openFile(slots["folder"] ?? name.map(\.raw).filter { !$0.isEmpty }.joined(separator: " "),
                                 folder: a.folder ?? (slots["folder"] != nil), reveal: a.reveal ?? false)]
        case "media": actions = [.media(a.key ?? "play")]
        case "scroll": actions = [.scroll(a.direction ?? "down", a.amount ?? 6)]
        case "type": actions = [.type(fill(a.text ?? ""))]
        case "openURL":
            let site = slots["site"].flatMap { config.sites?[$0] }
            if let template = a.url { actions = [.openURL(fill(template, encode: true))] }
            else if let site, slots["query"] != nil, let search = site.search { actions = [.openURL(fill(search, encode: true))] }
            else if let site { actions = [.openURL(site.url)] }
            else if let url = slots["url"] { actions = [.openURL(url.contains("://") ? url : "https://" + url)] }
            else { actions = [.notConfigured("no URL for \(cmd.id)")] }
        case "keys":
            let k = fill(a.keys ?? "TODO")
            actions = [k.uppercased().hasPrefix("TODO") ? .notConfigured(a.note ?? cmd.id) : .keys(k)]
        case "sequence":
            actions = (a.steps ?? []).map { s in
                if s.hasPrefix("type:") { return .type(fill(String(s.dropFirst(5)))) }
                if s.hasPrefix("wait:") { return .wait(Int(s.dropFirst(5)) ?? 100) }
                if s.hasPrefix("open:") { return .openApp(String(s.dropFirst(5))) }
                if s.hasPrefix("url:") { return .openURL(fill(String(s.dropFirst(4)), encode: true)) }
                return s.uppercased().hasPrefix("TODO") ? .notConfigured(a.note ?? cmd.id) : .keys(fill(s))
            }
        default: actions = [.notConfigured("unknown action type \(a.type)")]
        }
        var say = cmd.say ?? cmd.id
        for (k, v) in slots { say = say.replacingOccurrences(of: "{\(k)}", with: slotValues[k]?.first { $0.value == v }?.key ?? v) }   // spoken name, not a path
        return Step(id: cmd.id, say: say, actions: actions, slots: slots, freeKey: slots.keys.first(where: isFree))
    }

    /// For "Didn't catch": the phrase sharing the most words with what was said.
    private func suggest(_ segment: String, app: String?) -> String? {
        let said = Set(canon(tokenize(segment)).filter { !$0.filler }.map(\.norm))
        var best: (phrase: String, score: Int)?
        for c in compiled where c.cmd.app == nil || c.cmd.app == app {
            let score = c.pattern.filter { !$0.isSlot && said.contains($0.norm) }.count
            if score > (best?.score ?? 0) { best = (c.cmd.phrases.first ?? "", score) }
        }
        return best?.phrase
    }

    // MARK: apps

    /// Alias → exact installed name → (fuzzy only) unique prefix → closest name within 1–2 typos.
    public func resolveApp(_ spoken: String, fuzzy: Bool) -> String? {
        let s = compact(spoken)
        let cacheKey = (fuzzy ? "~" : "=") + s
        if let hit = appCache[cacheKey] { return hit }
        var result: String?
        if s.isEmpty { result = nil }
        else if let a = config.apps.first(where: { compact($0.key) == s }) { result = a.value }
        else if let a = installedApps.first(where: { compact($0) == s }) { result = a }
        else if let a = appAliases.first(where: { compact($0.key) == s }) { result = a.value }
        else if let a = config.apps.values.first(where: { compact($0) == s }) { result = a }
        else if fuzzy, s.count >= 3 {
            let names = installedApps.map { ($0, $0) } + appAliases.map { ($0.key, $0.value) }
            let prefixed = Set(names.filter { compact($0.0).hasPrefix(s) }.map(\.1))
            if prefixed.count == 1 { result = prefixed.first } else {
                let maxDist = s.count >= 8 ? 2 : 1
                let scored = (names + config.apps.map { ($0.key, $0.value) }).map { ($0.1, levenshtein(compact($0.0), s)) }.filter { $0.1 <= maxDist }
                if let best = scored.min(by: { $0.1 < $1.1 }), Set(scored.filter({ $0.1 == best.1 }).map(\.0)).count == 1 { result = best.0 }
            }
        }
        appCache[cacheKey] = result
        return result
    }

    // MARK: text

    struct Tok { var norm: String; var raw: String; var filler = false; var isSlot: Bool { norm.hasPrefix("{") } }

    func tokenize(_ s: String) -> [Tok] {
        s.split(whereSeparator: { $0.isWhitespace }).compactMap { word -> Tok? in
            let raw = String(word).trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?\"“”'()"))
            if raw.hasPrefix("{") { return Tok(norm: raw.lowercased(), raw: raw) }
            let norm = raw.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "`" }
            return norm.isEmpty ? nil : Tok(norm: norm, raw: raw)
        }
    }

    /// Replace synonyms (longest first) and mark filler words. Raw text is kept for slots.
    func canon(_ toks: [Tok]) -> [Tok] {
        var out: [Tok] = []
        var i = 0
        outer: while i < toks.count {
            if !toks[i].isSlot {
                for (from, to) in synonyms where i + from.count <= toks.count && toks[i..<i + from.count].map(\.norm) == from {
                    let raw = toks[i..<i + from.count].map(\.raw).joined(separator: " ")
                    out += to.enumerated().map { Tok(norm: $0.element, raw: $0.offset == 0 ? raw : "") }
                    i += from.count
                    continue outer
                }
                for f in fillers where i + f.count <= toks.count && toks[i..<i + f.count].map(\.norm) == f {
                    out += toks[i..<i + f.count].map { var t = $0; t.filler = true; return t }
                    i += f.count
                    continue outer
                }
            }
            out.append(toks[i]); i += 1
        }
        return out
    }

    func key(_ toks: [Tok]) -> String { toks.filter { !$0.filler }.map(\.norm).joined(separator: " ") }
    /// Rule 3 for any text: "Export as PDF…" → "export as pdf".
    public func normalize(_ s: String) -> String { key(canon(tokenize(s.replacingOccurrences(of: "&", with: " and ")))) }
    func compact(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber } }
}

func levenshtein(_ a: String, _ b: String) -> Int {
    let a = Array(a), b = Array(b)
    guard !a.isEmpty, !b.isEmpty else { return max(a.count, b.count) }
    var row = Array(0...b.count)
    for i in 1...a.count {
        var prev = row[0]; row[0] = i
        for j in 1...b.count {
            let cur = row[j]
            row[j] = min(row[j] + 1, row[j - 1] + 1, prev + (a[i - 1] == b[j - 1] ? 0 : 1))
            prev = cur
        }
    }
    return row[b.count]
}
