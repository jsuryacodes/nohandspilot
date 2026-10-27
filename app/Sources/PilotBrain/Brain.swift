// Brain: text in, plan out. Foundation only, no macOS APIs, so a Windows "Hands" can reuse it.
//
// Matching rules (keep the web version identical):
//  1. Trigger: text must start with a trigger word ("pilot", "hey pilot", ...), ignoring case and
//     punctuation. The bar passes requireTrigger=false.
//  2. Chain split on , ; . ! ? and the words "then" / "and then". A segment that doesn't match and
//     contains "and" is retried as two commands split on "and".
//  3. Words are lowercased, punctuation dropped, synonyms replaced (longest first) and filler words
//     skipped. Phrases go through the same steps, so "Open the new tab." == "open new tab".
//  4. Command words must match exactly. Slots: {app} = app name (alias, exact, prefix, or 1–2 typos),
//     anything else ({query}, {text}) = free text kept as spoken, must be non-empty.
//  5. Commands scoped to the current app are tried first, then global ones; more literal words wins.
//     The current app follows the chain: after "open chrome", Chrome commands apply.
//  6. "<command> in <app>" runs the command in that app (switching to it first).
//  7. A segment equal to a macro name expands to the macro's commands.
//  8. A segment that doesn't match right after a free-text command is appended to its text
//     ("type hello, how are you" types "hello, how are you").
//  9. If any segment still doesn't match, nothing runs.
import Foundation

public struct Config: Codable {
    public var triggerWords: [String]
    public var fillerWords: [String]
    public var synonyms: [String: String]
    public var apps: [String: String]
    public var hotkey: String?
    public var commands: [Command]
    public var macros: [String: [String]]
}

public struct Command: Codable {
    public var id: String
    public var app: String?
    public var phrases: [String]
    public var action: ActionSpec
    public var say: String?
}

public struct ActionSpec: Codable {
    public var type: String          // openApp | quitApp | keys | type | sequence | scroll | help
    public var keys: String?
    public var text: String?
    public var steps: [String]?
    public var direction: String?
    public var note: String?
}

public enum Action: Equatable {
    case openApp(String), quitApp(String), keys(String), type(String), scroll(String), wait(Int), help
    case notConfigured(String)
}

public struct Step: Equatable {
    public var id: String
    public var say: String
    public var actions: [Action]
    var freeText: String? = nil      // for rule 8
}

public enum Plan: Equatable {
    case notForPilot                 // no trigger word: leave the text alone
    case run([Step])
    case unmatched(String)           // the segment we couldn't understand
}

public final class Brain {
    public let config: Config
    let installedApps: [String]
    private var compiled: [(cmd: Command, pattern: [Tok], literals: Int)] = []

    public init(config: Config, installedApps: [String] = []) {
        self.config = config
        self.installedApps = installedApps
        for cmd in config.commands {
            for phrase in cmd.phrases {
                let pattern = canon(tokenize(phrase)).filter { !$0.filler }
                compiled.append((cmd, pattern, pattern.filter { !$0.isSlot }.count))
            }
        }
        compiled.sort { $0.literals > $1.literals }   // stable: JSON order breaks ties
    }

    public convenience init(json: Data, installedApps: [String] = []) throws {
        self.init(config: try JSONDecoder().decode(Config.self, from: json), installedApps: installedApps)
    }

    /// Text after the trigger word, or nil if the text isn't addressed to Pilot.
    public func stripTrigger(_ text: String) -> String? {
        let words = config.triggerWords.sorted { $0.count > $1.count }
            .map { $0.split(separator: " ").map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: "[\\s,.!:]+") }
        let re = try! NSRegularExpression(pattern: "^[\\s\"'“]*(?:\(words.joined(separator: "|")))\\b[\\s,.!:;-]*", options: .caseInsensitive)
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(from: m.range.upperBound)
    }

    public func plan(_ text: String, frontmostApp: String?, requireTrigger: Bool = true) -> Plan {
        var body = text
        if let rest = stripTrigger(text) { body = rest } else if requireTrigger { return .notForPilot }
        switch planChain(body, app: frontmostApp, depth: 0) {
        case .success(let steps): return steps.isEmpty ? .unmatched(body.trimmingCharacters(in: .whitespaces)) : .run(steps)
        case .failure(let e): return .unmatched(e.segment)
        }
    }

    // MARK: chain

    struct Miss: Error { var segment: String }

    private func planChain(_ text: String, app: String?, depth: Int) -> Result<[Step], Miss> {
        let segments = text.replacingOccurrences(of: "(?i)[,;!?]+|\\.(?=\\s|$)|\\band then\\b|\\bthen\\b", with: "\u{1}", options: .regularExpression)
            .split(separator: "\u{1}").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var steps: [Step] = []
        var app = app
        var freeIndex: Int?              // last step, if it ends in free text
        for seg in segments where !key(canon(tokenize(seg))).isEmpty {   // skip "um,"
            if let s = planSegment(seg, app: &app, depth: depth) {
                steps += s
                freeIndex = steps.last?.freeText != nil ? steps.count - 1 : nil
                continue
            }
            if seg.range(of: "\\band\\b", options: [.regularExpression, .caseInsensitive]) != nil {
                let parts = seg.components(separatedBy: " and ").map { $0.trimmingCharacters(in: .whitespaces) }
                var tmpApp = app, sub: [Step] = [], ok = !parts.contains("")
                for p in parts where ok { if let s = planSegment(p, app: &tmpApp, depth: depth) { sub += s } else { ok = false } }
                if ok { steps += sub; app = tmpApp; freeIndex = nil; continue }
            }
            if let i = freeIndex, let cmd = config.commands.first(where: { $0.id == steps[i].id }) {   // rule 8
                steps[i] = makeStep(cmd, slots: freeSlots(cmd, steps[i].freeText! + ", " + seg))
                continue
            }
            return .failure(Miss(segment: seg))
        }
        return .success(steps)
    }

    /// One command, possibly "<command> in <app>", or a macro.
    private func planSegment(_ seg: String, app: inout String?, depth: Int) -> [Step]? {
        let toks = canon(tokenize(seg))
        if depth < 3, let macro = config.macros.first(where: { key(canon(tokenize($0.key))) == key(toks) }) {
            var out: [Step] = []
            for line in macro.value {
                guard case .success(let s) = planChain(line, app: app, depth: depth + 1) else { return nil }
                for step in s { if case .openApp(let a)? = step.actions.first { app = a } }
                out += s
            }
            return out
        }
        // rule 6: "... in chrome"
        let words = seg.split(separator: " ")
        if let i = words.lastIndex(where: { ["in", "on"].contains($0.lowercased()) }), i > 0, i < words.count - 1,
           let target = resolveApp(words[(i + 1)...].joined(separator: " "), fuzzy: true) {
            if var step = match(canon(tokenize(words[..<i].joined(separator: " "))), app: target) {
                    if !step.actions.contains(.openApp(target)) { step.actions.insert(.openApp(target), at: 0) }
                app = target
                return [step]
            }
        }
        guard let step = match(toks, app: app) else { return nil }
        if case .openApp(let a)? = step.actions.first { app = a }
        return [step]
    }

    // MARK: matching

    private func match(_ toks: [Tok], app: String?) -> Step? {
        let scoped = compiled.filter { $0.cmd.app != nil && $0.cmd.app == app }
        let global = compiled.filter { $0.cmd.app == nil }
        for c in scoped + global {
            if let slots = bind(c.pattern, toks, strictApp: c.cmd.action.type == "quitApp") { return makeStep(c.cmd, slots: slots) }
        }
        return nil
    }

    /// Slot values if the pattern matches the whole token list, else nil.
    private func bind(_ pattern: [Tok], _ toks: [Tok], strictApp: Bool) -> [String: String]? {
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
            // try longest span first so free text swallows as much as possible
            for end in stride(from: toks.count, to: ti, by: -1) {
                let raw = toks[ti..<end].map(\.raw).filter { !$0.isEmpty }.joined(separator: " ")
                let trimmed = raw.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                var value = trimmed
                if name == "app" {
                    guard let a = resolveApp(trimmed, fuzzy: !strictApp) else { continue }
                    value = a
                }
                var next = acc; next[name] = value
                if let r = go(pi + 1, end, next) { return r }
            }
            return nil
        }
        return go(0, 0, [:])
    }

    private func freeSlots(_ cmd: Command, _ text: String) -> [String: String] {
        var s: [String: String] = [:]
        for p in cmd.phrases { for name in p.split(separator: "{").dropFirst().compactMap({ $0.split(separator: "}").first }) where name != "app" { s[String(name)] = text } }
        return s
    }

    private func makeStep(_ cmd: Command, slots: [String: String]) -> Step {
        func fill(_ s: String) -> String {
            var s = s
            for (k, v) in slots { s = s.replacingOccurrences(of: "{\(k)}", with: v) }
            return s
        }
        let a = cmd.action
        var actions: [Action] = []
        switch a.type {
        case "openApp": actions = [.openApp(slots["app"] ?? cmd.app ?? "")]
        case "quitApp": actions = [.quitApp(slots["app"] ?? "")]
        case "help": actions = [.help]
        case "scroll": actions = [.scroll(a.direction ?? "down")]
        case "type": actions = [.type(fill(a.text ?? ""))]
        case "keys":
            let k = a.keys ?? "TODO"
            actions = [k.uppercased().hasPrefix("TODO") ? .notConfigured(a.note ?? cmd.id) : .keys(k)]
        case "sequence":
            actions = (a.steps ?? []).map { s in
                if s.hasPrefix("type:") { return .type(fill(String(s.dropFirst(5)))) }
                if s.hasPrefix("wait:") { return .wait(Int(s.dropFirst(5)) ?? 100) }
                if s.hasPrefix("open:") { return .openApp(String(s.dropFirst(5))) }
                return s.uppercased().hasPrefix("TODO") ? .notConfigured(a.note ?? cmd.id) : .keys(s)
            }
        default: actions = [.notConfigured("unknown action type \(a.type)")]
        }
        return Step(id: cmd.id, say: fill(cmd.say ?? cmd.id), actions: actions, freeText: slots.first { $0.key != "app" }?.value)
    }

    // MARK: apps

    /// Alias → exact installed name → unique prefix → closest name within 1–2 typos.
    public func resolveApp(_ spoken: String, fuzzy: Bool) -> String? {
        let s = compact(spoken)
        guard !s.isEmpty else { return nil }
        if let a = config.apps.first(where: { compact($0.key) == s }) { return a.value }
        if let a = installedApps.first(where: { compact($0) == s }) { return a }
        if let a = config.apps.values.first(where: { compact($0) == s }) { return a }
        guard fuzzy, s.count >= 3 else { return nil }
        let prefixed = installedApps.filter { compact($0).hasPrefix(s) }
        if prefixed.count == 1 { return prefixed[0] }
        let maxDist = s.count >= 8 ? 2 : 1
        let scored = (installedApps + Array(config.apps.keys)).map { ($0, levenshtein(compact($0), s)) }.filter { $0.1 <= maxDist }
        guard let best = scored.min(by: { $0.1 < $1.1 }), scored.filter({ $0.1 == best.1 }).count == 1 else { return nil }
        return config.apps[best.0] ?? best.0
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
        let syn = config.synonyms.map { (canonKey($0.key).split(separator: " ").map(String.init), canonKey($0.value).split(separator: " ").map(String.init)) }
            .sorted { $0.0.count > $1.0.count }
        let fillers = config.fillerWords.map { canonKey($0).split(separator: " ").map(String.init) }.sorted { $0.count > $1.count }
        var out: [Tok] = []
        var i = 0
        outer: while i < toks.count {
            for (from, to) in syn where i + from.count <= toks.count && toks[i..<i + from.count].map(\.norm) == from && !toks[i].isSlot {
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
            out.append(toks[i]); i += 1
        }
        return out
    }

    func canonKey(_ s: String) -> String { tokenize(s).map(\.norm).joined(separator: " ") }
    func key(_ toks: [Tok]) -> String { toks.filter { !$0.filler }.map(\.norm).joined(separator: " ") }
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
