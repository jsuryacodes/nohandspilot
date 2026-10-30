// The mock Mac: what each of Pilot's actions does to it, and what Pilot's HUD says back. Pure functions of the
// desktop's state, so the command → effect mapping is tested without a browser (sim.test.ts). Behaviour follows
// Hands.swift and Screen.swift: opening an app that has no window opens one, numbers go when another app comes
// forward, "pause" on a paused video says "Already paused", and the errors are worded as Pilot words them.
import type { Action, Step } from '../brain/brain';
import { APPS, brain, config, keysLabel, SLOTS, type App } from '../brain/site';
import { FILES, HELP_ROWS } from './files';
import { addressTarget, NEW_TAB, page } from './pages';

export type Win = App | 'Help'; // "What can I say?" is Pilot's second window
export type Focus = 'address' | 'composer' | 'search' | 'prompt';
export const FOLDERS = ['Home', 'Desktop', 'Documents', 'Downloads', 'Applications'] as const;
export type Folder = (typeof FOLDERS)[number];

export interface Tab {
  id: number;
  history: string[];
  at: number;
  scroll: number; // screens down the page
  playing?: boolean; // a watch page's video
  draft?: string; // typed in the address bar, not entered yet (undefined: the address is selected)
}

export interface Desk {
  windows: Win[]; // back to front
  running: App[];
  front: App; // the active app: Finder when nothing else is
  history: App[]; // the order apps came forward, for "switch back"
  hidden: App[];
  minimised: Win[];
  full?: Win;
  numbers: boolean | string[]; // true: everything clickable; a list: just those (a tie for click by name), in that order
  focus?: Focus; // where typing goes in the front app
  chrome: { tabs: Tab[]; active: number; closed: Tab[]; next: number };
  code: { terminal: boolean; sidebar: boolean; file: string };
  claude: { sidebar: boolean; messages: string[]; draft: string };
  finder: { folder: Folder; back: Folder[]; sidebar: boolean; search: string };
  music: { playing: boolean; station: string; search: string };
  terminal: { lines: string[]; draft: string };
  settings: { pane: string };
  pilot: { source: boolean }; // "Build from source" unfolded
  scroll: Partial<Record<Win, number>>; // screens down, for windows other than Chrome
}

export const initial: Desk = {
  windows: [],
  running: ['Finder'],
  front: 'Finder',
  history: ['Finder'],
  hidden: [],
  minimised: [],
  numbers: false,
  chrome: { tabs: [], active: 0, closed: [], next: 1 },
  code: { terminal: false, sidebar: true, file: 'commands.json' },
  claude: { sidebar: true, messages: [], draft: '' },
  finder: { folder: 'Documents', back: [], sidebar: true, search: '' },
  music: { playing: false, station: '', search: '' },
  terminal: { lines: [], draft: '' },
  settings: { pane: 'Wi-Fi' },
  pilot: { source: false },
  scroll: {},
};

// Quitting an app forgets its state
const RESET: Record<App, Partial<Desk>> = {
  Finder: { finder: initial.finder },
  'Google Chrome': { chrome: initial.chrome },
  'Visual Studio Code': { code: initial.code },
  Claude: { claude: initial.claude },
  Terminal: { terminal: initial.terminal },
  Music: { music: initial.music },
  'System Settings': { settings: initial.settings },
  NoHandsPilot: { pilot: initial.pilot },
};

export const CHATS = ['Docker bridge networks', 'A Swift menu-bar app', 'Regex for dates'];
export const STATIONS = ['Feel Good', 'Relax', 'Focus', 'Chill', 'Workout', 'Sleep'];
// Settings panes, from the settings_* commands' own URLs and names ("Bluetooth settings" → "Bluetooth")
export const PANES: Record<string, string> = Object.fromEntries(
  config.commands
    .filter((c) => c.action.url?.startsWith('x-apple.systempreferences:'))
    .map((c) => [c.action.url, (c.say ?? c.id).replace(/ settings$/, '')]),
);
export const FINDER: Record<Folder, { name: string; open?: Folder | App }[]> = {
  Home: [
    { name: 'Applications', open: 'Applications' },
    { name: 'Desktop', open: 'Desktop' },
    { name: 'Documents', open: 'Documents' },
    { name: 'Downloads', open: 'Downloads' },
  ],
  Desktop: [{ name: 'demo-script.md' }, { name: 'notes.txt' }],
  Documents: [{ name: 'setup.md' }, { name: 'demo.md' }, { name: 'plan-review.md' }],
  Downloads: [{ name: 'NoHandsPilot.zip' }],
  Applications: APPS.map((a) => ({ name: a, open: a })),
};

export const appOf = (w: Win): App => (w === 'Help' ? 'NoHandsPilot' : w);
const isApp = (name: string): name is App => (APPS as readonly string[]).includes(name);
export const isShown = (d: Desk, w: Win) =>
  !d.hidden.includes(appOf(w)) && !d.minimised.includes(w);

/** The window typing and scrolling go to: the front app's topmost visible window. */
export function frontWindow(d: Desk): Win | undefined {
  return d.windows.findLast((w) => appOf(w) === d.front && isShown(d, w));
}

export const tabOf = (d: Desk): Tab | undefined => d.chrome.tabs[d.chrome.active];
export const urlOf = (t: Tab) => t.history[t.at];

/** How far a window can scroll, in screens. */
function length(d: Desk, w: Win): number {
  if (w === 'Google Chrome') {
    const t = tabOf(d);
    return t ? page(urlOf(t)).length : 1;
  }
  if (w === 'Visual Studio Code') return Math.max(1, FILES[d.code.file].split('\n').length / 30);
  if (w === 'Help') return Math.max(1, HELP_ROWS / 22);
  if (w === 'NoHandsPilot') return 2.2;
  return 1;
}

// MARK: outcomes

/** What one action did: changed the desktop (with an optional HUD note or a real page to open), can only be
 *  done on a Mac, or failed the way Pilot reports it. */
type Outcome = { desk: Desk; note?: string; link?: string } | { mac: true } | { error: string };
const ok = (desk: Desk, note?: string, link?: string): Outcome => ({ desk, note, link });
const MAC: Outcome = { mac: true };
const fail = (error: string): Outcome => ({ error });

export interface StepResult {
  desk: Desk;
  kind: 'done' | 'mac' | 'error';
  line: string; // what the HUD says for this step
  link?: string;
}

/** Runs one step of a plan: every action it can do here, then "On your Mac: …" for the first one it can't. */
export function runStep(d: Desk, step: Step): StepResult {
  let desk = d;
  let note: string | undefined;
  let link: string | undefined;
  for (const [i, a] of step.actions.entries()) {
    const r = act(desk, a);
    if ('error' in r) return { desk: d, kind: 'error', line: r.error };
    if ('mac' in r)
      return { desk, kind: 'mac', line: `On your Mac: ${describe(step.actions.slice(i))}` };
    desk = r.desk;
    note = r.note ?? note;
    link = r.link ?? link;
  }
  return { desk, kind: 'done', line: note ?? step.say, link };
}

/** What Pilot's Hands do on a Mac, for the actions the website can't: "presses ⌘⇧T". */
export function describe(actions: Action[]): string {
  const profile = (dir: string) => SLOTS.profile.find(([, v]) => v === dir)?.[0] ?? dir;
  const media: Record<string, string> = {
    play: 'presses the media key',
    pause: 'presses the media key',
    playPause: 'presses the media key',
    next: 'skips to the next track',
    previous: 'goes back a track',
    volumeUp: 'turns the volume up',
    volumeDown: 'turns the volume down',
    mute: 'mutes the sound',
  };
  const one = (a: Action): string => {
    switch (a.kind) {
      case 'openApp':
        return `opens ${a.app}`;
      case 'quitApp':
        return `quits ${a.app}`;
      case 'hideApp':
        return `hides ${a.app}`;
      case 'previousApp':
        return 'switches back to the last app';
      case 'openURL':
        if (a.url.includes('{selection}')) return "uses the text you've selected";
        if (a.url.startsWith('x-apple.systempreferences:'))
          return 'opens that pane of System Settings';
        if (a.url.startsWith('dict:')) return 'looks it up in Dictionary';
        return `opens ${a.url}`;
      case 'chromeProfile':
        return `opens Chrome in the ${profile(a.profile)} profile`;
      case 'keys':
        return `presses ${keysLabel(a.keys)}`;
      case 'type':
        return a.text.includes('{selection}')
          ? "types the text you've selected"
          : `types "${a.text}"`;
      case 'scroll':
        return `scrolls ${a.direction}`;
      case 'media':
        return media[a.key] ?? `presses ${a.key}`;
      case 'wait':
        return '';
      case 'help':
        return 'opens What can I say?';
      case 'menu':
        return `picks ${a.path.join(' › ')}`;
      case 'click':
        return `clicks "${a.target}"`;
      case 'numbers':
        return a.show ? 'numbers everything clickable' : 'hides the numbers';
      case 'pasteScreenshot':
        return 'pastes your latest screenshot, then puts back what you copied';
      case 'copyLink':
        return `copies the address of the link "${a.target}"`;
      case 'selectText':
        return `${{ select: 'selects', delete: 'deletes', cut: 'cuts' }[a.op] ?? 'copies'} "${a.phrase}" in the text field`;
      case 'playMusic':
        return `plays "${a.query}" from your Music library, or the first song Apple Music finds`;
      case 'openFile':
        return a.reveal
          ? `shows "${a.name}" in Finder`
          : `finds "${a.name}" with Spotlight and opens it`;
      case 'listen':
        return a.on
          ? 'listens for "Pilot" with its offline recognizer'
          : 'stops listening for "Pilot"';
      case 'dictate':
        return 'starts Wispr Flow to type what you say next';
      case 'notConfigured':
        return 'nothing yet';
    }
  };
  return actions.map(one).filter(Boolean).join(', ');
}

// MARK: actions

function act(d: Desk, a: Action): Outcome {
  switch (a.kind) {
    case 'openApp':
      return isApp(a.app) ? ok(activate(d, a.app)) : MAC;
    case 'quitApp':
      if (!isApp(a.app)) return MAC;
      return d.running.includes(a.app) ? ok(quit(d, a.app)) : fail(`${a.app} isn't running`);
    case 'hideApp':
      if (!isApp(a.app)) return MAC;
      return d.running.includes(a.app) ? ok(hide(d, a.app)) : fail(`${a.app} isn't running`);
    case 'previousApp': {
      const prev = d.history.findLast((x) => x !== d.front && d.running.includes(x));
      return prev ? ok(activate(d, prev)) : fail('No previous app yet');
    }
    case 'openURL':
      if (a.url.includes('{selection}')) return MAC;
      if (/^https?:/.test(a.url)) return ok(openInChrome(d, a.url));
      if (PANES[a.url])
        return ok({ ...activate(d, 'System Settings'), settings: { pane: PANES[a.url] } });
      return MAC;
    case 'keys':
      return keys(d, a.keys);
    case 'type':
      return type(d, a.text);
    case 'scroll':
      if (a.direction === 'left' || a.direction === 'right') return MAC;
      return scroll(d, ((a.direction === 'up' ? -1 : 1) * a.amount) / 12);
    case 'media':
      return media(d, a.key);
    case 'wait':
      return ok(d);
    case 'help':
      return ok(raise(open(activate(d, 'NoHandsPilot', false), 'Help'), 'Help'));
    case 'click':
      return click(d, a.target);
    case 'copyLink':
      return click(d, a.target, true);
    case 'selectText':
      return selectText(d, a.phrase, a.op, a.click);
    case 'numbers':
      return numbers(d, a.show);
    case 'openFile':
      if (!a.folder || !(FOLDERS as readonly string[]).includes(a.name)) return MAC;
      return ok(openFolder(activate(d, 'Finder'), a.name as Folder), `Opened ${a.name}`);
    case 'notConfigured':
      return fail(`Not set up yet: ${a.note}`);
    default: // chromeProfile, menu, listen, dictate, playMusic, pasteScreenshot
      return MAC;
  }
}

const add = <T>(list: T[], x: T) => (list.includes(x) ? list : [...list, x]);

/** Puts a window on the desktop if it isn't there yet. */
function open(d: Desk, w: Win): Desk {
  return d.windows.includes(w) ? d : { ...d, windows: [...d.windows, w] };
}

/** Brings a window to the top. */
function raise(d: Desk, w: Win): Desk {
  return {
    ...d,
    windows: [...d.windows.filter((x) => x !== w), w],
    minimised: d.minimised.filter((x) => x !== w),
  };
}

/** Like clicking the app in the Dock (Hands.openApp): it comes forward, unhides, and opens its window if that isn't
 *  open (or brings it back if minimised). `reopen: false` is a click on one of its windows instead. */
export function activate(d: Desk, app: App, reopen = true): Desk {
  let next: Desk = {
    ...d,
    running: add(d.running, app),
    hidden: d.hidden.filter((x) => x !== app),
    front: app,
    history: [...d.history.filter((x) => x !== app), app],
    focus: d.front === app ? d.focus : undefined,
    numbers: d.front === app && d.numbers,
  };
  if (reopen) next = raise(open(next, app), app);
  next = {
    ...next,
    windows: [
      ...next.windows.filter((w) => appOf(w) !== app),
      ...next.windows.filter((w) => appOf(w) === app),
    ],
  };
  if (app === 'Google Chrome' && !next.chrome.tabs.length) next = newTab(next, NEW_TAB);
  return next;
}

/** Focus a window by clicking it. */
export function focusWindow(d: Desk, w: Win): Desk {
  const app = appOf(w);
  return raise(activate(d, app, false), w);
}

function nextFront(d: Desk, gone: App): App {
  return (
    d.history.findLast((x) => x !== gone && d.running.includes(x) && !d.hidden.includes(x)) ??
    'Finder'
  );
}

function hide(d: Desk, app: App): Desk {
  const next = { ...d, hidden: add(d.hidden, app) };
  return d.front === app
    ? { ...next, front: nextFront(next, app), focus: undefined, numbers: false }
    : next;
}

export function quit(d: Desk, app: App): Desk {
  const next: Desk = {
    ...d,
    ...RESET[app],
    running: app === 'Finder' ? d.running : d.running.filter((x) => x !== app), // Finder can't really quit
    windows: d.windows.filter((w) => appOf(w) !== app),
    minimised: d.minimised.filter((w) => appOf(w) !== app),
    hidden: d.hidden.filter((x) => x !== app),
    history: app === 'Finder' ? d.history : d.history.filter((x) => x !== app),
    full: d.full && appOf(d.full) === app ? undefined : d.full,
  };
  return d.front === app
    ? { ...next, front: nextFront(next, app), focus: undefined, numbers: false }
    : next;
}

export function closeWindow(d: Desk, w: Win): Desk {
  const next: Desk = {
    ...d,
    windows: d.windows.filter((x) => x !== w),
    minimised: d.minimised.filter((x) => x !== w),
    full: d.full === w ? undefined : d.full,
    focus: undefined,
    numbers: false,
  };
  return w === 'Google Chrome'
    ? { ...next, chrome: { ...next.chrome, tabs: [], active: 0 } }
    : next;
}

export function minimise(d: Desk, w: Win): Desk {
  return {
    ...d,
    minimised: add(d.minimised, w),
    full: d.full === w ? undefined : d.full,
    focus: undefined,
    numbers: false,
  };
}

export function toggleFull(d: Desk, w: Win): Desk {
  return { ...d, full: d.full === w ? undefined : w };
}

// MARK: Chrome

function setTab(d: Desk, patch: Partial<Tab>, at = d.chrome.active): Desk {
  const tabs = d.chrome.tabs.map((t, i) => (i === at ? { ...t, ...patch } : t));
  return { ...d, chrome: { ...d.chrome, tabs } };
}

const autoplay = (url: string) => (page(url).kind === 'watch' ? true : undefined);

export function newTab(d: Desk, url: string): Desk {
  const c = d.chrome;
  const blank = url === NEW_TAB;
  const tab: Tab = {
    id: c.next,
    history: [url],
    at: 0,
    scroll: 0,
    playing: autoplay(url),
    draft: blank ? '' : undefined,
  };
  return {
    ...d,
    chrome: { ...c, tabs: [...c.tabs, tab], active: c.tabs.length, next: c.next + 1 },
    focus: blank ? 'address' : undefined,
  };
}

export function navigate(d: Desk, url: string): Desk {
  const t = tabOf(d);
  if (!t) return newTab(d, url);
  const history = [...t.history.slice(0, t.at + 1), url];
  return {
    ...setTab(d, {
      history,
      at: history.length - 1,
      scroll: 0,
      playing: autoplay(url),
      draft: undefined,
    }),
    focus: undefined,
    numbers: false,
  };
}

/** A link opened from outside Chrome lands in a new tab; a Chrome that's only just opened uses its first tab. */
function openInChrome(d: Desk, url: string): Desk {
  const opening = !d.windows.includes('Google Chrome');
  const next = activate(d, 'Google Chrome');
  return opening ? navigate(next, url) : newTab(next, url);
}

export function selectTab(d: Desk, i: number): Desk {
  return i >= 0 && i < d.chrome.tabs.length
    ? { ...d, chrome: { ...d.chrome, active: i }, focus: undefined, numbers: false }
    : d;
}

export function closeTab(d: Desk, i = d.chrome.active): Desk {
  const c = d.chrome;
  const t = c.tabs[i];
  if (!t) return d;
  const tabs = c.tabs.filter((_, j) => j !== i);
  const active = Math.max(0, i < c.active || c.active >= tabs.length ? c.active - 1 : c.active);
  const next: Desk = {
    ...d,
    chrome: { ...c, tabs, active, closed: [...c.closed, t] },
    focus: undefined,
    numbers: false,
  };
  return tabs.length ? next : closeWindow(next, 'Google Chrome');
}

function chromeKeys(d: Desk, k: string): Outcome | undefined {
  const c = d.chrome;
  const t = tabOf(d);
  if (k === 'cmd+t')
    return ok(
      d.windows.includes('Google Chrome') ? newTab(d, NEW_TAB) : activate(d, 'Google Chrome'),
    );
  if (!t) return undefined;
  const at = (i: number) => {
    const url = t.history[i];
    return ok({
      ...setTab(d, { at: i, scroll: 0, playing: autoplay(url), draft: undefined }),
      focus: undefined,
      numbers: false,
    });
  };
  switch (k) {
    case 'cmd+w':
      return ok(closeTab(d));
    case 'cmd+shift+t': {
      const last = c.closed[c.closed.length - 1];
      if (!last) return ok(d);
      return ok({
        ...d,
        chrome: {
          ...c,
          tabs: [...c.tabs, last],
          active: c.tabs.length,
          closed: c.closed.slice(0, -1),
        },
        focus: undefined,
        numbers: false,
      });
    }
    case 'ctrl+tab':
      return ok(selectTab(d, (c.active + 1) % c.tabs.length));
    case 'ctrl+shift+tab':
      return ok(selectTab(d, (c.active - 1 + c.tabs.length) % c.tabs.length));
    case 'cmd+l':
      return ok({ ...setTab(d, { draft: undefined }), focus: 'address', numbers: false });
    case 'cmd+[':
      return t.at > 0 ? at(t.at - 1) : ok(d);
    case 'cmd+]':
      return t.at < t.history.length - 1 ? at(t.at + 1) : ok(d);
    case 'cmd+r':
      return ok(setTab(d, { scroll: 0 }));
    case 'cmd+shift+w':
      return ok(closeWindow(d, 'Google Chrome'));
  }
  const n = /^cmd\+([1-9])$/.exec(k);
  if (n) return ok(selectTab(d, n[1] === '9' ? c.tabs.length - 1 : Number(n[1]) - 1));
  return undefined;
}

// MARK: keys, typing, scrolling, media

const FINDER_KEYS: Record<string, Folder> = {
  'cmd+opt+l': 'Downloads',
  'cmd+shift+d': 'Desktop',
  'cmd+shift+o': 'Documents',
  'cmd+shift+a': 'Applications',
  'cmd+shift+h': 'Home',
};

export function openFolder(d: Desk, folder: Folder): Desk {
  const f = d.finder;
  const at = raise(open(d, 'Finder'), 'Finder');
  return f.folder === folder && d.windows.includes('Finder')
    ? at
    : {
        ...at,
        finder: { ...f, folder, back: [...f.back, f.folder], search: '' },
        scroll: { ...d.scroll, Finder: 0 },
      };
}

/** A shortcut pressed by mouse (a toolbar button): its effect if the mock Mac has one. */
export function keyPress(d: Desk, k: string): Desk {
  const r = keys(d, k);
  return 'desk' in r ? r.desk : d;
}

function keys(d: Desk, k: string): Outcome {
  const app = d.front;
  const w = frontWindow(d);
  if (app === 'Google Chrome') {
    const r = chromeKeys(d, k);
    if (r) return r;
  }
  if (app === 'Visual Studio Code' && w) {
    if (k === 'ctrl+`') return ok({ ...d, code: { ...d.code, terminal: !d.code.terminal } });
    if (k === 'cmd+b') return ok({ ...d, code: { ...d.code, sidebar: !d.code.sidebar } });
    if (k === 'cmd+shift+e') return ok({ ...d, code: { ...d.code, sidebar: true } });
  }
  if (app === 'Claude' && w) {
    if (k === 'cmd+b') return ok({ ...d, claude: { ...d.claude, sidebar: !d.claude.sidebar } });
    if (k === 'cmd+n')
      return ok({ ...d, claude: { ...d.claude, messages: [], draft: '' }, focus: 'composer' });
  }
  if (app === 'Finder') {
    if (FINDER_KEYS[k]) return ok(openFolder(d, FINDER_KEYS[k]));
    if (k === 'ctrl+cmd+s' && w)
      return ok({ ...d, finder: { ...d.finder, sidebar: !d.finder.sidebar } });
    if (k === 'cmd+[' && w) {
      const back = d.finder.back;
      return back.length
        ? ok({
            ...d,
            finder: { ...d.finder, folder: back[back.length - 1], back: back.slice(0, -1) },
          })
        : ok(d);
    }
    if (k === 'cmd+up' && w) return ok(d.finder.folder === 'Home' ? d : openFolder(d, 'Home'));
    if (k === 'cmd+f' && w) return ok({ ...d, focus: 'search' });
  }
  if (app === 'Music' && w && k === 'cmd+f') return ok({ ...d, focus: 'search' });
  switch (k) {
    case 'cmd+m':
      return ok(w ? minimise(d, w) : d);
    case 'ctrl+cmd+f':
      return ok(w ? toggleFull(d, w) : d);
    case 'cmd+h':
      return ok(hide(d, app));
    case 'cmd+w':
      return ok(w ? closeWindow(d, w) : d);
    case 'cmd+`':
      return ok(d);
    case 'cmd+up':
      return scroll(d, 'top');
    case 'cmd+down':
      return scroll(d, 'bottom');
    case 'enter':
      return submit(d);
    case 'esc':
      return d.focus || d.numbers ? ok({ ...d, focus: undefined, numbers: false }) : MAC;
  }
  return MAC;
}

function submit(d: Desk): Outcome {
  switch (d.focus) {
    case 'address': {
      const text = tabOf(d)?.draft ?? '';
      return ok(text.trim() ? navigate(d, addressTarget(text)) : { ...d, focus: undefined });
    }
    case 'composer': {
      const said = d.claude.draft.trim();
      return ok(
        said
          ? { ...d, claude: { ...d.claude, messages: [...d.claude.messages, said], draft: '' } }
          : d,
      );
    }
    case 'search':
      return ok({ ...d, focus: undefined });
    case 'prompt':
      return ok({ ...d, terminal: { lines: [...d.terminal.lines, d.terminal.draft], draft: '' } });
  }
  return MAC;
}

function type(d: Desk, text: string): Outcome {
  if (text.includes('{selection}')) return MAC;
  switch (d.focus) {
    case 'address':
      return ok(setTab(d, { draft: (tabOf(d)?.draft ?? '') + text }));
    case 'composer':
      return ok({ ...d, claude: { ...d.claude, draft: d.claude.draft + text } });
    case 'search':
      return ok(
        d.front === 'Finder'
          ? { ...d, finder: { ...d.finder, search: d.finder.search + text } }
          : { ...d, music: { ...d.music, search: d.music.search + text } },
      );
    case 'prompt':
      return ok({ ...d, terminal: { ...d.terminal, draft: d.terminal.draft + text } });
  }
  if (frontWindow(d) === 'Terminal')
    return ok({
      ...d,
      focus: 'prompt',
      terminal: { ...d.terminal, draft: d.terminal.draft + text },
    });
  return MAC;
}

function scroll(d: Desk, by: number | 'top' | 'bottom'): Outcome {
  const w = frontWindow(d);
  if (!w) return fail('No window to scroll');
  const max = Math.max(0, length(d, w) - 1);
  const now = w === 'Google Chrome' ? (tabOf(d)?.scroll ?? 0) : (d.scroll[w] ?? 0);
  const to = by === 'top' ? 0 : by === 'bottom' ? max : Math.min(max, Math.max(0, now + by));
  return ok(
    w === 'Google Chrome' ? setTab(d, { scroll: to }) : { ...d, scroll: { ...d.scroll, [w]: to } },
  );
}

/** The player whose button is on screen (Screen.playPause), else what the media key would reach. */
function media(d: Desk, key: string): Outcome {
  if (key !== 'play' && key !== 'pause' && key !== 'playPause') return MAC;
  const w = frontWindow(d);
  const t = tabOf(d);
  const onScreen =
    w === 'Google Chrome' && t && page(urlOf(t)).kind === 'watch'
      ? 'chrome'
      : w === 'Music' && d.music.station
        ? 'music'
        : undefined;
  if (onScreen) {
    const playing = onScreen === 'chrome' ? !!t?.playing : d.music.playing;
    if (key !== 'playPause' && playing === (key === 'play'))
      return ok(d, playing ? 'Already playing' : 'Already paused');
    return ok(setPlaying(d, onScreen, !playing), playing ? 'Paused' : 'Playing');
  }
  // No player on screen: the media key, which toggles whatever plays in the background (Music, or a video in a
  // Chrome tab), else the last one paused. Nothing at all: on a Mac it would start Music.
  if (d.music.playing) return ok(setPlaying(d, 'music', false), 'Paused');
  const tabs = d.chrome.tabs;
  const tab =
    tabs.findIndex((x) => x.playing) >= 0
      ? tabs.findIndex((x) => x.playing)
      : tabs.findIndex((x) => x.playing === false);
  if (tab >= 0)
    return ok(
      setTab(d, { playing: !tabs[tab].playing }, tab),
      tabs[tab].playing ? 'Paused' : 'Playing',
    );
  if (d.music.station) return ok(setPlaying(d, 'music', true), 'Playing');
  return MAC;
}

function setPlaying(d: Desk, player: 'chrome' | 'music', playing: boolean): Desk {
  return player === 'music' ? { ...d, music: { ...d.music, playing } } : setTab(d, { playing });
}

// MARK: click and numbers

/** Something you can click, by mouse or by saying "click …". `id` is how the page finds it for its badge. */
export interface Clickable {
  id: string;
  name: string;
  press: (d: Desk) => Outcome;
  url?: string; // a link's address, for "copy link"
}
export const cid = (w: Win, key: string) => `${w}:${key}`;

/** Everything clickable in a window, in reading order: the order "show numbers" numbers them. */
export function clickables(d: Desk, w: Win): Clickable[] {
  const item = (key: string, name: string, press: Clickable['press']): Clickable => ({
    id: cid(w, key),
    name,
    press,
  });
  switch (w) {
    case 'Google Chrome': {
      const t = tabOf(d);
      if (!t) return [];
      return page(urlOf(t)).items.map((it) => ({
        ...item(it.name, it.play ? (t.playing ? 'Pause (k)' : 'Play (k)') : it.name, (x) => {
          if (it.play) return media(x, 'playPause');
          if (it.focus) return ok({ ...setTab(x, { draft: undefined }), focus: 'address' });
          if (it.link) return ok(x, undefined, it.link);
          return ok(navigate(x, it.to ?? NEW_TAB));
        }),
        url: it.link ?? it.to,
      }));
    }
    case 'Finder': {
      const side = d.finder.sidebar
        ? FOLDERS.map((f) => item(`side:${f}`, f, (x) => ok(openFolder(x, f))))
        : [];
      const q = d.finder.search.toLowerCase();
      const files = FINDER[d.finder.folder]
        .filter((f) => f.name.toLowerCase().includes(q))
        .map((f) =>
          item(`file:${f.name}`, f.name, (x) => {
            if (!f.open) return MAC;
            return (FOLDERS as readonly string[]).includes(f.open)
              ? ok(openFolder(x, f.open as Folder))
              : ok(activate(x, f.open as App));
          }),
        );
      return [...side, ...files];
    }
    case 'Visual Studio Code': {
      const files = d.code.sidebar
        ? Object.keys(FILES).map((f) =>
            item(`file:${f}`, f, (x) =>
              ok({ ...x, code: { ...x.code, file: f }, scroll: { ...x.scroll, [w]: 0 } }),
            ),
          )
        : [];
      return [
        item('Explorer', 'Explorer', (x) =>
          ok({ ...x, code: { ...x.code, sidebar: !x.code.sidebar } }),
        ),
        ...files,
      ];
    }
    case 'Claude': {
      const chats = d.claude.sidebar
        ? CHATS.map((c) =>
            item(`chat:${c}`, c, (x) =>
              ok({ ...x, claude: { ...x.claude, messages: [c], draft: '' } }),
            ),
          )
        : [];
      const send = d.claude.draft.trim()
        ? [item('Send', 'Send', (x) => submit({ ...x, focus: 'composer' }))]
        : [];
      return [
        item('New chat', 'New chat', (x) =>
          ok({ ...x, claude: { ...x.claude, messages: [], draft: '' }, focus: 'composer' }),
        ),
        ...chats,
        ...send,
      ];
    }
    case 'Music': {
      const button = d.music.station
        ? [item('player', d.music.playing ? 'Pause' : 'Play', (x) => media(x, 'playPause'))]
        : [];
      return [
        ...button,
        ...STATIONS.map((s) =>
          item(`station:${s}`, s, (x) =>
            ok({ ...x, music: { ...x.music, station: s, playing: true } }),
          ),
        ),
      ];
    }
    case 'System Settings':
      return Object.values(PANES).map((p) =>
        item(p, p, (x) => ok({ ...x, settings: { pane: p } })),
      );
    case 'NoHandsPilot':
      return [
        item('download', 'Download for Mac', (x) =>
          ok(x, undefined, `${REPO_URL}/releases/latest`),
        ),
        item('source', 'Build from source', (x) =>
          ok({ ...x, pilot: { source: !x.pilot.source } }),
        ),
        item('github', 'View on GitHub', (x) => ok(x, undefined, REPO_URL)),
      ];
    default:
      return [];
  }
}
const REPO_URL = 'https://github.com/jsuryacodes/nohandspilot';

/** Presses something by mouse: the same effect as saying "click" on it, without the HUD. */
export function press(d: Desk, id: string): { desk: Desk; link?: string } {
  const w = id.slice(0, id.indexOf(':')) as Win;
  const c = clickables(d, w).find((x) => x.id === id);
  if (!c) return { desk: d };
  const r = c.press(focusWindow(d, w));
  return 'desk' in r ? { desk: { ...r.desk, numbers: false }, link: r.link } : { desk: d };
}

function numbers(d: Desk, show: boolean): Outcome {
  if (!show) return ok({ ...d, numbers: false });
  const w = frontWindow(d);
  const n = w ? clickables(d, w).length : 0;
  if (!n) return fail(`Nothing to number in ${d.front}`);
  return ok({ ...d, numbers: true }, `${n} numbers. Say "click" and a number`);
}

/** What the badges are on, in badge order: everything clickable, or just the tied matches of a click by name. */
export function badged(d: Desk, w: Win): Clickable[] {
  const items = clickables(d, w);
  const ids = d.numbers;
  return Array.isArray(ids) ? ids.flatMap((id) => items.filter((c) => c.id === id)) : items;
}

/** Screen.ordinal: "first one", "second", "last one" (normalised) → a badge number, of `count` badges. */
export function ordinal(t: string, count: number): number | undefined {
  const words = [
    'first',
    'second',
    'third',
    'fourth',
    'fifth',
    'sixth',
    'seventh',
    'eighth',
    'ninth',
    'tenth',
  ];
  const w = t.endsWith(' one') ? t.slice(0, -4) : t;
  if (w === 'last') return count > 0 ? count : undefined;
  const i = words.indexOf(w);
  return i < 0 ? undefined : i + 1;
}

/** Hands' selectText on the one text field here, Claude's message box: the phrase (ignoring case, the last one),
 *  then delete, cut, copy or just select. With nothing to type into, "select X" is a click. */
function selectText(d: Desk, phrase: string, op: string, target: string): Outcome {
  if (d.focus === 'composer' && d.front === 'Claude') {
    const draft = d.claude.draft;
    const at = draft.toLowerCase().lastIndexOf(phrase.toLowerCase());
    if (at < 0) return fail(`No text field here with "${phrase}" in it`);
    const found = draft.slice(at, at + phrase.length);
    const gone = op === 'delete' || op === 'cut';
    const verb =
      ({ delete: 'Deleted', cut: 'Cut', copy: 'Copied' } as Record<string, string>)[op] ??
      'Selected';
    return ok(
      gone
        ? {
            ...d,
            claude: { ...d.claude, draft: draft.slice(0, at) + draft.slice(at + phrase.length) },
          }
        : d,
      `${verb} "${found}"`,
    );
  }
  if (d.focus) return MAC; // the address bar, a search field, the prompt: no mock selection there
  return op === 'select' ? click(d, target) : fail(`No text field here with "${phrase}" in it`);
}

/** Screen.click: a badge's number while numbers are up, else the element whose name equals the target, starts
 *  with it, or contains all its words (best tier wins). Two or more at the same tier get numbers of their own. */
function click(d: Desk, target: string, link = false): Outcome {
  const w = frontWindow(d);
  if (!w || !target) return fail(link ? 'No link to copy' : 'Nothing to click');
  const verb = link ? 'copy link' : 'click';
  const items = clickables(d, w).filter((c) => !link || c.url);
  const run = (c: Clickable, note: string): Outcome => {
    if (link) return ok({ ...d, numbers: false }, `Copied link: ${c.url}`);
    const r = c.press(d);
    return 'desk' in r ? { ...r, desk: { ...r.desk, numbers: false }, note: r.note ?? note } : r;
  };
  if (d.numbers) {
    // "click 2", or "the second one" / "the last one" while badges are up, means that badge
    const shown = badged(d, w);
    const n = /^\d+$/.test(target) ? Number(target) : ordinal(target, shown.length);
    if (n !== undefined) {
      const c = shown[n - 1];
      return c
        ? run(c, `Clicked ${n}` + (c.name ? ` "${c.name}"` : ''))
        : fail(`No number ${target} on screen`);
    }
  }
  const best = (t: string) => {
    const words = t.split(' ');
    let tier = 3;
    let hits: Clickable[] = [];
    for (const c of items) {
      const n = brain.normalize(c.name);
      if (!n) continue;
      const own = n.split(' ');
      const at =
        n === t
          ? 0
          : (n + ' ').startsWith(t + ' ')
            ? 1
            : words.every((x) => own.includes(x))
              ? 2
              : 3;
      if (at < tier) [tier, hits] = [at, [c]];
      else if (at === tier && at < 3) hits.push(c);
    }
    return hits;
  };
  let hits = best(target);
  const suffix = / (button|link|tab|icon|field|box|checkbox|option)$/;
  if (!hits.length && suffix.test(target)) hits = best(target.replace(suffix, '')); // "the send button"
  if (!hits.length) return fail(`Couldn't find ${link ? 'a link ' : ''}"${target}" on screen`);
  if (hits.length > 1) {
    // a tie: number just those, in reading order, and let you pick
    const n = hits.length;
    return ok(
      { ...d, numbers: hits.map((c) => c.id) },
      `${n} × "${hits[0].name}": say ` +
        (n === 2 ? `"${verb} 1" or "${verb} 2"` : `"${verb} 1" to "${verb} ${n}"`),
    );
  }
  return run(hits[0], `Clicked "${hits[0].name}"`);
}
