// Port of app/Sources/PilotBrain/Brain.swift: text in, plan out. The matching rules are documented at the top
// of that file. Keep the two identical; if they ever disagree, the Swift is right.

export interface Site {
  url: string;
  search?: string;
}

export interface ActionSpec {
  type: string;
  keys?: string;
  text?: string;
  url?: string;
  key?: string;
  steps?: string[];
  direction?: string;
  amount?: number;
  note?: string;
  folder?: boolean;
  reveal?: boolean;
}

export interface Command {
  id: string;
  app?: string;
  phrases: string[];
  action: ActionSpec;
  say?: string;
}

export interface Config {
  triggerWords: string[];
  fillerWords: string[];
  synonyms: Record<string, string>;
  apps: Record<string, string>;
  browser?: string;
  sites?: Record<string, Site>;
  hotkey?: string;
  commands: Command[];
  macros: Record<string, string[]>;
}

export type Action =
  | { kind: 'openApp'; app: string }
  | { kind: 'quitApp'; app: string }
  | { kind: 'hideApp'; app: string }
  | { kind: 'previousApp' }
  | { kind: 'openURL'; url: string }
  | { kind: 'chromeProfile'; profile: string }
  | { kind: 'keys'; keys: string }
  | { kind: 'type'; text: string }
  | { kind: 'scroll'; direction: string; amount: number }
  | { kind: 'media'; key: string }
  | { kind: 'wait'; ms: number }
  | { kind: 'help' }
  | { kind: 'menu'; app: string; path: string[] } // app, title path: ("Google Chrome", ["Tab", "Duplicate Tab"])
  | { kind: 'click'; target: string } // a visible element by name, normalised as in rule 3, or a badge number ("12")
  | { kind: 'numbers'; show: boolean }
  | { kind: 'openFile'; name: string; folder: boolean; reveal: boolean }
  | { kind: 'notConfigured'; note: string };

export interface Step {
  id: string;
  say: string;
  actions: Action[];
  slots: Record<string, string>;
  freeKey?: string; // slot holding free text, for rule 7
}

export type Plan =
  | { kind: 'notForPilot' } // no trigger word: leave the text alone
  | { kind: 'run'; steps: Step[] }
  | { kind: 'unmatched'; segment: string; suggestion?: string }
  | { kind: 'teach'; phrase?: string; commands: string[] } // rule 1b; no phrase = "teach that" (the last miss)
  | { kind: 'forget'; phrase: string };

/** Runtime slot values, e.g. { profile: [["Jaya Surya", "Profile 2"], ...] }. Earlier entries win ties. */
export type SlotValues = Record<string, [key: string, value: string][]>;

interface Tok {
  norm: string;
  raw: string;
  filler: boolean;
}
interface Ctx {
  app?: string;
  explicit: boolean; // the current app was chosen by this chain (not just whatever happened to be in front)
}
type Chain = { steps: Step[] } | { miss: { segment: string; app?: string } };

const BUILTIN_SLOTS = new Set(['app', 'site', 'n', 'url']);
const isSlot = (t: Tok) => t.norm.startsWith('{');
const compact = (s: string) => s.toLowerCase().replace(/[^\p{L}\p{N}]/gu, '');
const words = (s: string) =>
  s
    .split(/\s+/)
    .map((w) => w.toLowerCase().replace(/[^\p{L}\p{N}`]/gu, ''))
    .filter(Boolean);
/** Swift's Int(s): optional sign and ASCII digits only. */
const int = (s: string) => (/^[+-]?\d+$/.test(s) ? parseInt(s, 10) : undefined);

export class Brain {
  readonly config: Config;
  /** Title paths of a running app's enabled menu items, e.g. [["File", "Export as PDF…"]] (rule 8). */
  menuItems?: (app: string) => string[][];
  private readonly installedApps: string[];
  /** Other names apps go by, e.g. { "OBS Studio": "OBS" } (display name → .app file name). */
  private readonly appAliases: Record<string, string>;
  private readonly slotValues: SlotValues;
  private readonly compiled: { cmd: Command; pattern: Tok[]; literals: number }[] = [];
  private readonly synonyms: [string[], string[]][];
  private readonly fillers: string[][];
  private readonly triggerRegex: RegExp;
  private readonly appCache = new Map<string, string | undefined>();
  private typos = true;
  private menus = true;

  constructor(
    config: Config,
    installedApps: string[] = [],
    appAliases: Record<string, string> = {},
    slotValues: SlotValues = {},
  ) {
    this.config = config;
    this.installedApps = installedApps;
    this.appAliases = appAliases;
    this.slotValues = slotValues;
    this.synonyms = Object.entries(config.synonyms)
      .map(([from, to]): [string[], string[]] => [words(from), words(to)])
      .sort((a, b) => b[0].length - a[0].length);
    this.fillers = config.fillerWords
      .map(words)
      .filter((f) => f.length)
      .sort((a, b) => b.length - a.length);
    const escape = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const triggers = [...config.triggerWords]
      .sort((a, b) => b.length - a.length)
      .map((t) => t.split(' ').filter(Boolean).map(escape).join('[\\s,.!:]+'));
    this.triggerRegex = new RegExp(`^[\\s"'“]*(?:${triggers.join('|')})\\b[\\s,.!:;-]*`, 'i');
    for (const cmd of config.commands) {
      for (const phrase of cmd.phrases) {
        const pattern = this.canon(this.tokenize(phrase)).filter((t) => !t.filler);
        this.compiled.push({ cmd, pattern, literals: pattern.filter((t) => !isSlot(t)).length });
      }
    }
    this.compiled.sort((a, b) => b.literals - a.literals); // stable: JSON order breaks ties
  }

  /** Text after the trigger word, or undefined if the text isn't addressed to Pilot. */
  stripTrigger(text: string): string | undefined {
    const m = this.triggerRegex.exec(text);
    return m ? text.slice(m[0].length) : undefined;
  }

  /**
   * `typos: false` skips typo-tolerant app names (step 6e), e.g. to ask whether a phrase is already taken.
   * `menus: false` skips menu items (rule 8), so nothing reads the screen.
   */
  plan(
    text: string,
    frontmostApp?: string,
    { requireTrigger = true, typos = true, menus = true } = {},
  ): Plan {
    this.typos = typos;
    this.menus = menus;
    try {
      let body = text;
      const rest = this.stripTrigger(text);
      if (rest !== undefined) body = rest;
      else if (requireTrigger) return { kind: 'notForPilot' };
      const teaching = this.teaching(body);
      if (teaching) return teaching;
      const r = this.planChain(body, frontmostApp, false, 0);
      if ('miss' in r) {
        return {
          kind: 'unmatched',
          segment: r.miss.segment,
          suggestion: this.suggest(r.miss.segment, r.miss.app),
        };
      }
      return r.steps.length
        ? { kind: 'run', steps: r.steps }
        : { kind: 'unmatched', segment: body.trim() };
    } finally {
      this.typos = true;
      this.menus = true;
    }
  }

  /** Rule 1b, on the raw text so commas stay inside: "when I say X, do A, B", "teach that: A", "that means A", "forget X". */
  private teaching(body: string): Plan | undefined {
    const s = body.trim();
    const clean = (t: string) => t.replace(/^[\s"“”'‘’.,:;!?]+|[\s"“”'‘’.,:;!?]+$/g, '');
    const commands = (t: string) =>
      this.segments(t).filter((seg) => this.key(this.canon(this.tokenize(seg))));
    let g = /^when i say\s+(.+?)[\s,]*\b(?:do|run)\b[\s:,]*(.+)$/i.exec(s);
    if (g) return { kind: 'teach', phrase: clean(g[1]), commands: commands(g[2]) };
    g = /^(?:teach that|that means)\b[\s:,-]*(.+)$/i.exec(s);
    if (g) return { kind: 'teach', commands: commands(g[1]) };
    g = /^forget\s+(.+)$/i.exec(s);
    if (g) return { kind: 'forget', phrase: clean(g[1]) };
    return undefined;
  }

  // MARK: chain

  /** Rule 2's split, without the "and" retry. */
  segments(text: string): string[] {
    return text
      .replace(/[,;!?]+|\.(?=\s|$)|\band then\b|\bthen\b/gi, '\u0001')
      .split('\u0001')
      .map((s) => s.trim())
      .filter(Boolean);
  }

  private planChain(
    text: string,
    app: string | undefined,
    explicit: boolean,
    depth: number,
  ): Chain {
    const ctx: Ctx = { app, explicit };
    const steps: Step[] = [];
    const lastFree = () =>
      steps.length && steps[steps.length - 1].freeKey !== undefined ? steps.length - 1 : undefined;
    let freeIndex: number | undefined;
    for (const seg of this.segments(text)) {
      if (!this.key(this.canon(this.tokenize(seg)))) continue; // skip "um,"
      const s = this.planSegment(seg, ctx, depth);
      if (s) {
        steps.push(...s);
        freeIndex = lastFree();
        continue;
      }
      if (/\band\b/i.test(seg)) {
        const parts = seg.split(' and ').map((p) => p.trim());
        const tmp: Ctx = { ...ctx };
        const sub: Step[] = [];
        let ok = !parts.includes('');
        for (const p of parts) {
          if (!ok) break;
          const r = this.planSegment(p, tmp, depth);
          if (r) sub.push(...r);
          else ok = false;
        }
        if (ok) {
          steps.push(...sub);
          Object.assign(ctx, tmp);
          freeIndex = lastFree();
          continue;
        }
      }
      const prev = freeIndex !== undefined ? steps[freeIndex] : undefined;
      const freeKey = prev?.freeKey;
      const cmd = prev && this.config.commands.find((c) => c.id === prev.id);
      if (freeIndex !== undefined && prev && freeKey !== undefined && cmd) {
        // rule 7
        const slots = { ...prev.slots, [freeKey]: (prev.slots[freeKey] ?? '') + ', ' + seg };
        const lead: Action[] = [];
        for (const a of prev.actions) {
          if (a.kind !== 'openApp') break;
          lead.push(a);
        }
        const merged = this.makeStep(cmd, slots);
        if (merged.actions[0]?.kind !== 'openApp') merged.actions.unshift(...lead);
        steps[freeIndex] = merged;
        continue;
      }
      const said = this.key(this.canon(this.tokenize(seg))); // rule 8
      const menuApp = ctx.app;
      const path =
        this.menus && menuApp !== undefined
          ? this.menuItems?.(menuApp).find((p) => this.normalize(p[p.length - 1] ?? '') === said)
          : undefined;
      if (menuApp !== undefined && path) {
        steps.push({
          id: 'menu',
          say: path.join(' › '),
          actions: [{ kind: 'menu', app: menuApp, path }],
          slots: {},
        });
        freeIndex = undefined;
        continue;
      }
      return { miss: { segment: seg, app: ctx.app } };
    }
    return { steps };
  }

  private planSegment(seg: string, ctx: Ctx, depth: number): Step[] | undefined {
    const toks = this.canon(this.tokenize(seg));
    // a. macro
    const said = this.key(toks);
    const macro =
      depth < 3
        ? Object.entries(this.config.macros).find(
            ([name]) => this.key(this.canon(this.tokenize(name))) === said,
          )
        : undefined;
    if (macro) {
      const out: Step[] = [];
      for (const line of macro[1]) {
        const r = this.planChain(line, ctx.app, ctx.explicit, depth + 1);
        if ('miss' in r) return undefined;
        for (const step of r.steps) {
          const a = this.contextApp(step);
          if (a !== undefined) Object.assign(ctx, { app: a, explicit: true });
        }
        out.push(...r.steps);
      }
      return out;
    }
    const done = (step: Step) => {
      const a = this.contextApp(step);
      if (a !== undefined) Object.assign(ctx, { app: a, explicit: true });
      return [step];
    };
    // b. exact; inside an app the chain switched to, prefer commands that stay there (rule 5)
    const current = ctx.app;
    if (ctx.explicit && current !== undefined) {
      const step = this.match(toks, current, false, (s) => this.stays(s, current));
      if (step) return done(step);
    }
    const exact = this.match(toks, current, false);
    if (exact) return done(exact);
    // c. "... in chrome"
    const ws = seg.split(' ').filter(Boolean);
    const i = ws.findLastIndex((w) => ['in', 'on'].includes(w.toLowerCase()));
    if (i > 0 && i < ws.length - 1) {
      const target = this.resolveApp(ws.slice(i + 1).join(' '), this.typos);
      if (target !== undefined) {
        const step = this.match(
          this.canon(this.tokenize(ws.slice(0, i).join(' '))),
          target,
          false,
          (s) => this.stays(s, target),
        );
        if (step) return done(this.inApp(step, target));
      }
    }
    // d. app named anywhere: "open a new chrome tab", "close the claude sidebar"
    if (ws.length > 1) {
      for (let len = Math.min(3, ws.length - 1); len >= 1; len--) {
        for (let start = 0; start <= ws.length - len; start++) {
          const target = this.resolveApp(ws.slice(start, start + len).join(' '), false);
          if (target === undefined) continue;
          const rest = [...ws];
          rest.splice(start, len);
          if (
            start > 0 &&
            ['in', 'on', 'using', 'with', 'from', 'of', 'inside'].includes(
              rest[start - 1].toLowerCase(),
            )
          ) {
            rest.splice(start - 1, 1);
          }
          const step = this.match(this.canon(this.tokenize(rest.join(' '))), target, false, (s) =>
            this.stays(s, target),
          );
          if (step) return done(this.inApp(step, target));
        }
      }
    }
    // e. exact, allowing typos in app names
    if (this.typos) {
      const step = this.match(toks, current, true);
      if (step) return done(step);
    }
    return undefined;
  }

  /** A command aimed at an app ("search X in WhatsApp") must not switch to a different app (Chrome). */
  private stays(step: Step, target: string): boolean {
    const browser = this.config.browser ?? 'Google Chrome';
    return step.actions.every(
      (a) =>
        !(a.kind === 'openApp' && a.app !== target) &&
        !((a.kind === 'openURL' || a.kind === 'chromeProfile') && target !== browser),
    );
  }

  /** Make sure the step runs in `target`: switch to it first unless the step already does. */
  private inApp(step: Step, target: string): Step {
    const first = step.actions[0]?.kind;
    if (first && ['openApp', 'quitApp', 'hideApp', 'openURL', 'chromeProfile'].includes(first))
      return step;
    return { ...step, actions: [{ kind: 'openApp', app: target }, ...step.actions] };
  }

  /** Which app is in front after this step, for scoping the next command in a chain. */
  private contextApp(step: Step): string | undefined {
    const browser = this.config.browser ?? 'Google Chrome';
    let app: string | undefined;
    for (const a of step.actions) {
      if (a.kind === 'openApp') app = a.app;
      else if (a.kind === 'openURL' && a.url.startsWith('http'))
        app = browser; // not Settings or dict: links
      else if (a.kind === 'chromeProfile') app = browser;
    }
    return app;
  }

  // MARK: matching

  private match(
    toks: Tok[],
    app: string | undefined,
    fuzzy: boolean,
    accept: (s: Step) => boolean = () => true,
  ): Step | undefined {
    const scoped = this.compiled.filter((c) => c.cmd.app !== undefined && c.cmd.app === app);
    const global = this.compiled.filter((c) => c.cmd.app === undefined);
    for (const c of [...scoped, ...global]) {
      const slots = this.bind(c.pattern, toks, fuzzy && c.cmd.action.type !== 'quitApp');
      if (!slots) continue;
      const step = this.makeStep(c.cmd, slots);
      if (accept(step)) return step;
    }
    return undefined;
  }

  private isFree(slot: string) {
    return !BUILTIN_SLOTS.has(slot) && this.slotValues[slot] === undefined;
  }

  /** Slot values if the pattern matches the whole token list. */
  private bind(pattern: Tok[], toks: Tok[], fuzzy: boolean): Record<string, string> | undefined {
    const go = (
      pi: number,
      ti: number,
      acc: Record<string, string>,
    ): Record<string, string> | undefined => {
      const skipFillers = () => {
        while (ti < toks.length && toks[ti].filler) ti++;
      };
      if (pi === pattern.length) {
        skipFillers();
        return ti === toks.length ? acc : undefined;
      }
      const p = pattern[pi];
      if (!isSlot(p)) {
        skipFillers();
        return ti < toks.length && toks[ti].norm === p.norm ? go(pi + 1, ti + 1, acc) : undefined;
      }
      const name = p.norm.slice(1, -1);
      const free = this.isFree(name);
      if (!free) skipFillers(); // "open the youtube"
      for (let end = toks.length; end > ti; end--) {
        // longest span first
        const span = toks.slice(ti, end);
        if (free && !span.some((t) => !t.filler)) continue; // "search this": no text, only a filler
        const raw = span
          .map((t) => t.raw)
          .filter(Boolean)
          .join(' ')
          .trim();
        const value = raw ? this.resolveSlot(name, raw, fuzzy) : undefined;
        if (value === undefined) continue;
        const r = go(pi + 1, end, { ...acc, [name]: value });
        if (r) return r;
      }
      return undefined;
    };
    return go(0, 0, {});
  }

  private resolveSlot(name: string, raw: string, fuzzy: boolean): string | undefined {
    switch (name) {
      case 'app':
        return this.resolveApp(raw, fuzzy);
      case 'site':
        return Object.keys(this.config.sites ?? {}).find((k) => compact(k) === compact(raw));
      case 'n':
        return number(raw);
      case 'url': {
        const r = raw.replace(/^[.,]+|[.,]+$/g, '');
        return /^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+(\/\S*)?$/.test(r) ? r : undefined;
      }
    }
    const values = this.slotValues[name];
    if (values) return this.resolveNamed(raw, values, fuzzy);
    // free text mustn't swallow a trailing "in chrome" / "on youtube" (rule 6b)
    const m = fuzzy ? null : /\s(in|on)\s+(.+)$/i.exec(raw);
    if (m) {
      const tail = m[0].split(' ').filter(Boolean).slice(1).join(' ');
      if (
        this.resolveApp(tail, false) !== undefined ||
        this.resolveSlot('site', tail, false) !== undefined
      ) {
        return undefined;
      }
    }
    return raw;
  }

  /** Exact (earlier entries win), then unique prefix, then (fuzzy pass) 1–2 typos. */
  private resolveNamed(
    raw: string,
    values: [string, string][],
    fuzzy: boolean,
  ): string | undefined {
    const s = compact(raw);
    if (!s) return undefined;
    const hit = values.find(([k]) => compact(k) === s);
    if (hit) return hit[1];
    const prefixed = new Set(values.filter(([k]) => compact(k).startsWith(s)).map(([, v]) => v));
    if (prefixed.size === 1 && s.length >= 3) return [...prefixed][0];
    if (!fuzzy) return undefined;
    const close = values.filter(([k]) => levenshtein(compact(k), s) <= (s.length >= 8 ? 2 : 1));
    return new Set(close.map(([, v]) => v)).size === 1 ? close[0][1] : undefined;
  }

  private makeStep(cmd: Command, slots: Record<string, string>): Step {
    const fill = (s: string, encode = false) =>
      Object.entries(slots).reduce(
        (out, [k, v]) => out.replaceAll(`{${k}}`, encode ? percentEncode(v) : v),
        s,
      );
    const a = cmd.action;
    let actions: Action[];
    switch (a.type) {
      case 'openApp':
        actions = [{ kind: 'openApp', app: slots.app ?? cmd.app ?? '' }];
        break;
      case 'quitApp':
        actions = [{ kind: 'quitApp', app: slots.app ?? '' }];
        break;
      case 'hideApp':
        actions = [{ kind: 'hideApp', app: slots.app ?? cmd.app ?? '' }];
        break;
      case 'previousApp':
        actions = [{ kind: 'previousApp' }];
        break;
      case 'chromeProfile':
        actions = [{ kind: 'chromeProfile', profile: slots.profile ?? '' }];
        break;
      case 'help':
        actions = [{ kind: 'help' }];
        break;
      case 'click': {
        const raw = slots.target ?? '';
        const n = spokenNumber(this.normalize(raw.replaceAll('-', ' ')));
        actions = [{ kind: 'click', target: n !== undefined ? String(n) : this.normalize(raw) }];
        break;
      }
      case 'showNumbers':
      case 'hideNumbers':
        actions = [{ kind: 'numbers', show: a.type === 'showNumbers' }];
        break;
      case 'openFile': {
        const name = this.canon(this.tokenize(slots.query ?? '')); // "my resume" → "resume"
        while (name[0]?.filler) name.shift();
        while (name[name.length - 1]?.filler) name.pop();
        actions = [
          {
            kind: 'openFile',
            name:
              slots.folder ??
              name
                .map((t) => t.raw)
                .filter(Boolean)
                .join(' '),
            folder: a.folder ?? slots.folder !== undefined,
            reveal: a.reveal ?? false,
          },
        ];
        break;
      }
      case 'media':
        actions = [{ kind: 'media', key: a.key ?? 'play' }];
        break;
      case 'scroll':
        actions = [{ kind: 'scroll', direction: a.direction ?? 'down', amount: a.amount ?? 6 }];
        break;
      case 'type':
        actions = [{ kind: 'type', text: fill(a.text ?? '') }];
        break;
      case 'openURL': {
        const site = slots.site !== undefined ? this.config.sites?.[slots.site] : undefined;
        if (a.url !== undefined) actions = [{ kind: 'openURL', url: fill(a.url, true) }];
        else if (site && slots.query !== undefined && site.search !== undefined)
          actions = [{ kind: 'openURL', url: fill(site.search, true) }];
        else if (site) actions = [{ kind: 'openURL', url: site.url }];
        else if (slots.url !== undefined)
          actions = [
            {
              kind: 'openURL',
              url: slots.url.includes('://') ? slots.url : 'https://' + slots.url,
            },
          ];
        else actions = [{ kind: 'notConfigured', note: `no URL for ${cmd.id}` }];
        break;
      }
      case 'keys': {
        const k = fill(a.keys ?? 'TODO');
        actions = [
          k.toUpperCase().startsWith('TODO')
            ? { kind: 'notConfigured', note: a.note ?? cmd.id }
            : { kind: 'keys', keys: k },
        ];
        break;
      }
      case 'sequence':
        actions = (a.steps ?? []).map((s): Action => {
          if (s.startsWith('type:')) return { kind: 'type', text: fill(s.slice(5)) };
          if (s.startsWith('wait:')) return { kind: 'wait', ms: int(s.slice(5)) ?? 100 };
          if (s.startsWith('open:')) return { kind: 'openApp', app: s.slice(5) };
          if (s.startsWith('url:')) return { kind: 'openURL', url: fill(s.slice(4), true) };
          return s.toUpperCase().startsWith('TODO')
            ? { kind: 'notConfigured', note: a.note ?? cmd.id }
            : { kind: 'keys', keys: fill(s) };
        });
        break;
      default:
        actions = [{ kind: 'notConfigured', note: `unknown action type ${a.type}` }];
    }
    let say = cmd.say ?? cmd.id;
    for (const [k, v] of Object.entries(slots)) {
      say = say.replaceAll(
        `{${k}}`,
        this.slotValues[k]?.find(([, value]) => value === v)?.[0] ?? v,
      ); // spoken name, not a path
    }
    return {
      id: cmd.id,
      say,
      actions,
      slots,
      freeKey: Object.keys(slots).find((k) => this.isFree(k)),
    };
  }

  /** For "Didn't catch": the phrase sharing the most words with what was said. */
  private suggest(segment: string, app?: string): string | undefined {
    const said = new Set(
      this.canon(this.tokenize(segment))
        .filter((t) => !t.filler)
        .map((t) => t.norm),
    );
    let best: { phrase: string; score: number } | undefined;
    for (const c of this.compiled) {
      if (c.cmd.app !== undefined && c.cmd.app !== app) continue;
      const score = c.pattern.filter((p) => !isSlot(p) && said.has(p.norm)).length;
      if (score > (best?.score ?? 0)) best = { phrase: c.cmd.phrases[0] ?? '', score };
    }
    return best?.phrase;
  }

  // MARK: apps

  /** Alias → exact installed name → (fuzzy only) unique prefix → closest name within 1–2 typos. */
  resolveApp(spoken: string, fuzzy: boolean): string | undefined {
    const s = compact(spoken);
    const cacheKey = (fuzzy ? '~' : '=') + s;
    if (this.appCache.has(cacheKey)) return this.appCache.get(cacheKey);
    let result = s
      ? (Object.entries(this.config.apps).find(([k]) => compact(k) === s)?.[1] ??
        this.installedApps.find((a) => compact(a) === s) ??
        Object.entries(this.appAliases).find(([k]) => compact(k) === s)?.[1] ??
        Object.values(this.config.apps).find((v) => compact(v) === s))
      : undefined;
    if (result === undefined && fuzzy && s.length >= 3) {
      const names: [string, string][] = [
        ...this.installedApps.map((a): [string, string] => [a, a]),
        ...Object.entries(this.appAliases),
      ];
      const prefixed = new Set(names.filter(([n]) => compact(n).startsWith(s)).map(([, v]) => v));
      if (prefixed.size === 1) result = [...prefixed][0];
      else {
        const maxDist = s.length >= 8 ? 2 : 1;
        const scored = [...names, ...Object.entries(this.config.apps)]
          .map(([n, v]) => ({ v, d: levenshtein(compact(n), s) }))
          .filter((x) => x.d <= maxDist);
        const min = Math.min(...scored.map((x) => x.d));
        const tied = new Set(scored.filter((x) => x.d === min).map((x) => x.v));
        if (tied.size === 1) result = [...tied][0];
      }
    }
    this.appCache.set(cacheKey, result);
    return result;
  }

  // MARK: text

  private tokenize(s: string): Tok[] {
    return s.split(/\s+/).flatMap((word): Tok[] => {
      const raw = word.replace(/^[.,;:!?"“”'()]+|[.,;:!?"“”'()]+$/g, '');
      if (raw.startsWith('{')) return [{ norm: raw.toLowerCase(), raw, filler: false }];
      const norm = raw.toLowerCase().replace(/[^\p{L}\p{N}`]/gu, '');
      return norm ? [{ norm, raw, filler: false }] : [];
    });
  }

  /** Replace synonyms (longest first) and mark filler words. Raw text is kept for slots. */
  private canon(toks: Tok[]): Tok[] {
    const out: Tok[] = [];
    const at = (i: number, ws: string[]) =>
      i + ws.length <= toks.length && ws.every((w, k) => toks[i + k].norm === w);
    let i = 0;
    outer: while (i < toks.length) {
      if (!isSlot(toks[i])) {
        for (const [from, to] of this.synonyms) {
          if (!at(i, from)) continue;
          const raw = toks
            .slice(i, i + from.length)
            .map((t) => t.raw)
            .join(' ');
          out.push(...to.map((norm, k) => ({ norm, raw: k === 0 ? raw : '', filler: false })));
          i += from.length;
          continue outer;
        }
        for (const f of this.fillers) {
          if (!at(i, f)) continue;
          out.push(...toks.slice(i, i + f.length).map((t) => ({ ...t, filler: true })));
          i += f.length;
          continue outer;
        }
      }
      out.push(toks[i]);
      i++;
    }
    return out;
  }

  private key(toks: Tok[]): string {
    return toks
      .filter((t) => !t.filler)
      .map((t) => t.norm)
      .join(' ');
  }

  /** Rule 3 for any text: "Export as PDF…" → "export as pdf". */
  normalize(s: string): string {
    return this.key(this.canon(this.tokenize(s.replaceAll('&', ' and '))));
  }
}

function number(raw: string): string | undefined {
  // prettier-ignore
  const words: Record<string, number> = {
    one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7, eight: 8, nine: 9,
    first: 1, second: 2, third: 3, fourth: 4, fifth: 5, sixth: 6, seventh: 7, eighth: 8, ninth: 9,
    '1st': 1, '2nd': 2, '3rd': 3, '4th': 4, '5th': 5, '6th': 6, '7th': 7, '8th': 8, '9th': 9, last: 9,
  };
  const w = raw.toLowerCase().replace(/^\p{P}+|\p{P}+$/gu, '');
  const n = int(w);
  if (n !== undefined && n >= 1 && n <= 9) return String(n);
  return Object.hasOwn(words, w) ? String(words[w]) : undefined;
}

/** Badge numbers for click: "12", "twelve", "twenty one", "a hundred and five" (normalised text). */
function spokenNumber(t: string): number | undefined {
  // prettier-ignore
  const units = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve',
    'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen'];
  const tens = ['twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];
  const ws = t.split(' ').filter((w) => w && w !== 'and');
  if (ws.length === 1 && int(ws[0]) !== undefined) return int(ws[0]);
  let n = 0;
  for (const w of ws) {
    if (units.includes(w)) n += units.indexOf(w);
    else if (tens.includes(w)) n += (tens.indexOf(w) + 2) * 10;
    else if (w === 'hundred') n = Math.max(n, 1) * 100;
    else return undefined;
  }
  return ws.length ? n : undefined;
}

/** Foundation's addingPercentEncoding(withAllowedCharacters: .alphanumerics): letters, marks and digits stay. */
function percentEncode(s: string): string {
  let out = '';
  for (const ch of s) {
    if (/[\p{L}\p{M}\p{N}]/u.test(ch)) out += ch;
    else
      for (const b of new TextEncoder().encode(ch))
        out += '%' + b.toString(16).toUpperCase().padStart(2, '0');
  }
  return out;
}

export function levenshtein(a: string, b: string): number {
  const x = [...a];
  const y = [...b];
  if (!x.length || !y.length) return Math.max(x.length, y.length);
  const row = Array.from({ length: y.length + 1 }, (_, j) => j);
  for (let i = 1; i <= x.length; i++) {
    let prev = row[0];
    row[0] = i;
    for (let j = 1; j <= y.length; j++) {
      const cur = row[j];
      row[j] = Math.min(row[j] + 1, row[j - 1] + 1, prev + (x[i - 1] === y[j - 1] ? 0 : 1));
      prev = cur;
    }
  }
  return row[y.length];
}
