// What's inside each mock app's window. Everything here only draws the simulation's state (sim.ts); a click calls
// `press` with the element's id, the same thing "click …" and "click 3" reach, and `act` for plain mouse moves
// like picking a tab. Pages are stand-ins and say so.
import { useState, type ReactNode } from 'react';
import type { App } from '../brain/site';
import { RELEASES_URL } from '../config';
import { AppIcon, Glyph, Icon } from './icons';
import { FILES, HELP, README } from './files';
import { NEW_TAB, page, type Page, type Video } from './pages';
import {
  CHATS,
  cid,
  closeTab,
  FINDER,
  FOLDERS,
  keyPress,
  newTab,
  PANES,
  selectTab,
  STATIONS,
  tabOf,
  urlOf,
  type Desk,
  type Tab,
  type Win,
} from './sim';
import { useScrollTo } from './Window';

export interface Ctx {
  d: Desk;
  press: (id: string) => void;
  act: (change: (d: Desk) => Desk) => void;
  run: (command: string) => void;
}

/** Something "click" can reach: a real button, tagged so "show numbers" can find it for its badge. */
function Hit({
  w,
  k,
  press,
  className = '',
  children,
  label,
}: {
  w: Win;
  k: string;
  press: Ctx['press'];
  className?: string;
  children: ReactNode;
  label?: string;
}) {
  const id = cid(w, k);
  return (
    <button
      type="button"
      data-click={id}
      aria-label={label}
      onClick={() => press(id)}
      className={`text-left ${className}`}
    >
      {children}
    </button>
  );
}

/** Chrome shows addresses decoded: "search?q=Docker networking", not %20. */
const safeDecode = (s: string) => {
  try {
    return decodeURIComponent(s);
  } catch {
    return s;
  }
};
const Caret = () => (
  <span
    aria-hidden
    className="ml-px inline-block h-[1.1em] w-px translate-y-[0.15em] animate-blink bg-os-text"
  />
);
const Title = ({ children }: { children: ReactNode }) => (
  <div className="pointer-events-none absolute inset-x-24 top-0 flex h-[38px] items-center justify-center truncate text-[13px] font-semibold text-os-text-2">
    {children}
  </div>
);
export const PlainTitle = ({ text }: { text: string }) => <Title>{text}</Title>;
const StandIn = ({ children }: { children: ReactNode }) => (
  <p className="rounded-sm border border-os-line px-3 py-2 text-[12px] text-os-text-2">
    {children}
  </p>
);

// MARK: Chrome

function Favicon({ p, playing }: { p: Page; playing?: boolean }) {
  const letter = p.kind === 'newtab' ? '' : (p.host || p.title).charAt(0).toUpperCase();
  return (
    <span
      aria-hidden
      className="relative grid size-4 shrink-0 place-items-center rounded-[4px] bg-os-control text-[9px] font-bold text-os-text-2"
    >
      {letter}
      {playing && (
        <span className="absolute -right-1 -top-1 size-2 rounded-full border border-os-chrome bg-os-text-2" />
      )}
    </span>
  );
}

export function ChromeTabs({ d, act }: Ctx) {
  const c = d.chrome;
  return (
    <div className="flex min-w-0 flex-1 items-end gap-0.5 pr-2">
      {c.tabs.map((t, i) => {
        const p = page(urlOf(t));
        const on = i === c.active;
        return (
          <div
            key={t.id}
            className={`flex h-[31px] min-w-0 max-w-[210px] flex-1 items-center rounded-t-[9px] pl-3 pr-1.5 ${on ? 'bg-os-window' : 'hover:bg-os-hover'}`}
          >
            <button
              type="button"
              aria-current={on ? 'page' : undefined}
              onClick={() => act((x) => selectTab(x, i))}
              className="flex min-w-0 flex-1 items-center gap-2 text-left"
            >
              <Favicon p={p} playing={t.playing} />
              <span className="truncate text-[12px]">{p.title}</span>
            </button>
            <button
              type="button"
              aria-label={`Close ${p.title}`}
              onClick={() => act((x) => closeTab(x, i))}
              className="group/x grid size-6 shrink-0 place-items-center text-os-text-2"
            >
              <span className="grid size-4 place-items-center rounded-full group-hover/x:bg-os-select">
                <Icon d={Glyph.close} className="size-3" />
              </span>
            </button>
          </div>
        );
      })}
      <button
        type="button"
        aria-label="New tab"
        onClick={() => act((x) => newTab(x, NEW_TAB))}
        className="mb-1 grid size-6 shrink-0 place-items-center rounded-full text-os-text-2 hover:bg-os-hover"
      >
        <Icon d={Glyph.plus} className="size-3.5" />
      </button>
    </div>
  );
}

export function ChromeBody(ctx: Ctx) {
  const { d, act } = ctx;
  const t = tabOf(d);
  const ref = useScrollTo(t?.scroll ?? 0);
  if (!t) return null;
  const url = urlOf(t);
  const p = page(url);
  const editing = d.focus === 'address';
  const typed = editing && t.draft !== undefined;
  const address = url === NEW_TAB ? '' : safeDecode(url.replace(/^https:\/\/(www\.)?/, ''));
  const tool = (label: string, glyph: string, keys: string, off = false) => (
    <button
      type="button"
      aria-label={label}
      disabled={off}
      onClick={() => act((x) => keyPress(x, keys))}
      className="grid size-7 place-items-center rounded-full text-os-text-2 hover:bg-os-hover disabled:opacity-40"
    >
      <Icon d={glyph} className="size-3.5" />
    </button>
  );
  return (
    <div className="flex h-full flex-col">
      <div className="flex h-[40px] shrink-0 items-center gap-0.5 border-b border-os-line bg-os-window px-2">
        {tool('Back', Glyph.back, 'cmd+[', t.at === 0)}
        {tool('Forward', Glyph.forward, 'cmd+]', t.at >= t.history.length - 1)}
        {tool('Reload', Glyph.reload, 'cmd+r')}
        <div
          className={`ml-1 flex h-[28px] min-w-0 flex-1 items-center gap-2 rounded-full bg-os-chrome px-3 ${editing ? 'outline-2 outline-os-text-2' : ''}`}
        >
          <Icon d={Glyph.search} className="size-3 shrink-0 text-os-text-2" />
          <span className="sr-only">Address: </span>
          <span
            className={`truncate ${editing && !typed && address ? 'rounded-[3px] bg-os-select' : ''}`}
          >
            {typed
              ? t.draft
              : address || <span className="text-os-text-2">Search Google or type a URL</span>}
          </span>
          {typed && <Caret />}
        </div>
      </div>
      <div ref={ref} className="min-h-0 flex-1 overflow-y-auto bg-os-window">
        <PageView p={p} t={t} {...ctx} />
      </div>
    </div>
  );
}

const W: Win = 'Google Chrome';

function SiteBar({
  name,
  press,
  children,
}: {
  name: string;
  press: Ctx['press'];
  children?: ReactNode;
}) {
  return (
    <div className="sticky top-0 z-10 flex h-[52px] items-center gap-5 border-b border-os-line bg-os-window px-5">
      <Hit w={W} k={name} press={press} className="text-[17px] font-bold tracking-tight">
        {name}
      </Hit>
      <Hit
        w={W}
        k="Search"
        press={press}
        className="flex h-[32px] max-w-[420px] flex-1 items-center gap-2 rounded-full border border-os-line bg-os-field px-3.5 text-os-text-2"
      >
        <Icon d={Glyph.search} className="size-3.5" />
        <span className="truncate">{children ?? 'Search'}</span>
      </Hit>
    </div>
  );
}

function Thumb({ v, big = false }: { v: Video; big?: boolean }) {
  return (
    <span
      aria-hidden
      className={`relative block aspect-video overflow-hidden ${big ? '' : 'rounded-sm'}`}
      style={{
        background: `radial-gradient(120% 90% at 30% 20%, hsl(${v.hue} 42% 46%), hsl(${(v.hue + 40) % 360} 38% 20%) 60%, hsl(${(v.hue + 80) % 360} 30% 10%))`,
      }}
    >
      {!big && (
        <span className="absolute bottom-1.5 right-1.5 rounded-[4px] bg-black/75 px-1 text-[11px] font-medium text-white">
          {v.length}
        </span>
      )}
    </span>
  );
}

function PageView({ p, t, press }: Ctx & { p: Page; t: Tab }) {
  switch (p.kind) {
    case 'newtab':
      return (
        <div className="flex min-h-full flex-col items-center justify-center gap-7 p-8">
          <Hit
            w={W}
            k="Search Google or type a URL"
            press={press}
            className="flex h-[42px] w-full max-w-[460px] items-center gap-3 rounded-full border border-os-line bg-os-field px-4 text-os-text-2 shadow-hud"
          >
            <Icon d={Glyph.search} />
            Search Google or type a URL
          </Hit>
          <div className="grid grid-cols-6 gap-3">
            {p.items.slice(1).map((it) => (
              <Hit
                key={it.name}
                w={W}
                k={it.name}
                press={press}
                className="flex w-[74px] flex-col items-center gap-2 rounded-md p-2 hover:bg-os-hover"
              >
                <span
                  aria-hidden
                  className="grid size-10 place-items-center rounded-full bg-os-chrome text-[15px] font-semibold"
                >
                  {it.name.charAt(0)}
                </span>
                <span className="w-full truncate text-center text-[11px]">{it.name}</span>
              </Hit>
            ))}
          </div>
        </div>
      );
    case 'google':
      return (
        <div className="flex min-h-full flex-col items-center justify-center gap-6 p-8">
          <p className="text-[34px] font-semibold tracking-tight">Google</p>
          <Hit
            w={W}
            k="Search"
            press={press}
            className="flex h-[42px] w-full max-w-[460px] items-center gap-3 rounded-full border border-os-line px-4 text-os-text-2"
          >
            <Icon d={Glyph.search} />
            Search
          </Hit>
        </div>
      );
    case 'results':
      return (
        <div>
          <SiteBar name="Google" press={press}>
            <span className="text-os-text">{p.query}</span>
          </SiteBar>
          <div className="max-w-[620px] space-y-6 px-5 py-5 pl-[86px]">
            <StandIn>
              Stand-in results. On your Mac, Pilot opens the real Google search in Chrome.
            </StandIn>
            {p.results.map((r) => (
              <Hit key={r.title} w={W} k={r.title} press={press} className="group block">
                <span className="block truncate text-[12px] text-os-text-2">
                  {safeDecode(r.url.replace(/^https:\/\//, ''))}
                </span>
                <span className="mt-0.5 block text-[17px] leading-snug group-hover:underline">
                  {r.title}
                </span>
                <span className="mt-1 block text-[13px] text-os-text-2">{r.text}</span>
              </Hit>
            ))}
          </div>
        </div>
      );
    case 'youtube':
    case 'ytresults':
      return (
        <div>
          <SiteBar name="YouTube" press={press}>
            {p.query && <span className="text-os-text">{p.query}</span>}
          </SiteBar>
          <div className="grid grid-cols-3 gap-x-4 gap-y-5 p-5">
            {p.videos.map((v) => (
              <Hit key={v.title} w={W} k={v.title} press={press} className="group block">
                <Thumb v={v} />
                <span className="mt-2 block">
                  <span className="line-clamp-2 block text-[14px] font-semibold leading-snug group-hover:underline">
                    {v.title}
                  </span>
                  <span className="mt-1 block text-[12px] text-os-text-2">{v.channel}</span>
                </span>
              </Hit>
            ))}
          </div>
        </div>
      );
    case 'watch': {
      const v = p.video!;
      return (
        <div>
          <SiteBar name="YouTube" press={press} />
          <div className="grid grid-cols-[1fr_220px] gap-5 p-5">
            <div>
              <div className="relative overflow-hidden rounded-md">
                <Thumb v={v} big />
                <Hit
                  w={W}
                  k="player"
                  press={press}
                  label={t.playing ? 'Pause (k)' : 'Play (k)'}
                  className="absolute inset-0 grid place-items-center"
                >
                  <span
                    className={`grid size-14 place-items-center rounded-full bg-black/55 text-white transition ${t.playing ? 'opacity-0 hover:opacity-100' : ''}`}
                  >
                    <Icon d={t.playing ? Glyph.pause : Glyph.play} className="size-6" />
                  </span>
                </Hit>
                <span aria-hidden className="absolute inset-x-0 bottom-0 h-1 bg-white/25">
                  <span
                    className="block h-full origin-left animate-progress bg-white/90"
                    style={{ animationPlayState: t.playing ? 'running' : 'paused' }}
                  />
                </span>
              </div>
              <p className="mt-3 text-[18px] font-semibold leading-snug">{v.title}</p>
              <p className="mt-1 text-[12px] text-os-text-2">
                {v.channel} · {t.playing ? 'Playing' : 'Paused'}
              </p>
            </div>
            <div className="space-y-3">
              {p.videos.map((n) => (
                <Hit
                  key={n.title}
                  w={W}
                  k={n.title}
                  press={press}
                  className="group grid grid-cols-[96px_1fr] gap-2"
                >
                  <Thumb v={n} />
                  <span className="line-clamp-2 text-[12px] font-semibold leading-snug group-hover:underline">
                    {n.title}
                  </span>
                </Hit>
              ))}
            </div>
          </div>
        </div>
      );
    }
    case 'github':
      return (
        <div>
          <SiteBar name="GitHub" press={press} />
          <div className="p-6">
            <p className="text-[12px] font-semibold text-os-text-2">Top repositories</p>
            <Hit
              w={W}
              k="jsuryacodes/nohandspilot"
              press={press}
              className="mt-3 flex items-center gap-3 rounded-md border border-os-line px-4 py-3 hover:bg-os-hover"
            >
              <AppIcon app="NoHandsPilot" className="size-6" />
              <span className="font-semibold">jsuryacodes/nohandspilot</span>
            </Hit>
          </div>
        </div>
      );
    case 'repo':
      return (
        <div>
          <SiteBar name="GitHub" press={press} />
          <div className="max-w-[760px] p-6">
            <div className="flex flex-wrap items-center gap-3">
              <AppIcon app="NoHandsPilot" className="size-7" />
              <p className="text-[18px]">
                jsuryacodes / <span className="font-semibold">nohandspilot</span>
              </p>
              <span className="flex-1" />
              <Hit
                w={W}
                k="Releases"
                press={press}
                className="rounded-sm border border-os-line px-3 py-1.5 font-medium hover:bg-os-hover"
              >
                Releases
              </Hit>
              <Hit
                w={W}
                k="Open on GitHub"
                press={press}
                className="rounded-sm bg-os-text px-3 py-1.5 font-medium text-os-window"
              >
                Open on GitHub
              </Hit>
            </div>
            <div className="mt-5 rounded-md border border-os-line p-6">
              <p className="mb-4 text-[12px] font-semibold text-os-text-2">README.md</p>
              <Markdown text={README} />
            </div>
          </div>
        </div>
      );
    case 'site':
      return (
        <div className="grid min-h-full place-items-center p-8 text-center">
          <div className="max-w-[380px]">
            <p className="text-[22px] font-semibold">{p.host}</p>
            <p className="mt-2 text-os-text-2">A stand-in page. On your Mac, Chrome opens</p>
            <p className="mt-1 break-all font-mono text-[12px]">{p.url}</p>
          </div>
        </div>
      );
  }
}

/** Just enough Markdown for the README: headings, paragraphs, bullets, code blocks, `code`, **bold**, links. */
function Markdown({ text }: { text: string }) {
  const inline = (s: string) =>
    s.split(/(`[^`]+`|\*\*[^*]+\*\*|\[[^\]]+\]\([^)]+\))/).map((part, i) => {
      if (part.startsWith('`'))
        return (
          <code key={i} className="rounded-[4px] bg-os-chrome px-1 font-mono text-[12px]">
            {part.slice(1, -1)}
          </code>
        );
      if (part.startsWith('**')) return <strong key={i}>{part.slice(2, -2)}</strong>;
      if (part.startsWith('['))
        return (
          <span key={i} className="underline">
            {part.slice(1, part.indexOf(']'))}
          </span>
        );
      return part;
    });
  const blocks: ReactNode[] = [];
  const lines = text.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.startsWith('```')) {
      const code: string[] = [];
      while (++i < lines.length && !lines[i].startsWith('```')) code.push(lines[i]);
      blocks.push(
        <pre key={i} className="overflow-x-auto rounded-sm bg-os-chrome p-3 font-mono text-[12px]">
          {code.join('\n')}
        </pre>,
      );
    } else if (line.startsWith('#')) {
      const level = line.indexOf(' ');
      blocks.push(
        <p key={i} className={`font-semibold ${level === 1 ? 'text-[22px]' : 'mt-2 text-[16px]'}`}>
          {line.slice(level + 1)}
        </p>,
      );
    } else if (line.startsWith('- ')) {
      const item = [line.slice(2)];
      while (i + 1 < lines.length && lines[i + 1].startsWith('  ')) item.push(lines[++i].trim());
      blocks.push(
        <p key={i} className="pl-4 -indent-3">
          • {inline(item.join(' '))}
        </p>,
      );
    } else if (line.trim()) {
      const para = [line];
      while (i + 1 < lines.length && lines[i + 1].trim() && !/^(#|- |```)/.test(lines[i + 1]))
        para.push(lines[++i]);
      blocks.push(<p key={i}>{inline(para.join(' '))}</p>);
    }
  }
  return <div className="space-y-3 leading-relaxed">{blocks}</div>;
}

// MARK: other apps

export function FinderTitle({ d }: Ctx) {
  return <Title>{d.finder.folder}</Title>;
}

export function FinderBody({ d, press, act }: Ctx) {
  const f = d.finder;
  const q = f.search.toLowerCase();
  return (
    <div className="flex h-full">
      {f.sidebar && (
        <nav aria-label="Favourites" className="w-[150px] shrink-0 space-y-0.5 bg-os-sidebar p-2">
          <p className="px-2 pb-1 pt-1 text-[11px] font-semibold text-os-text-2">Favourites</p>
          {FOLDERS.map((name) => (
            <Hit
              key={name}
              w="Finder"
              k={`side:${name}`}
              press={press}
              className={`flex w-full items-center gap-2 rounded-sm px-2 py-1 ${name === f.folder ? 'bg-os-select' : 'hover:bg-os-hover'}`}
            >
              <Icon d={Glyph.folder} className="size-4 text-os-text-2" />
              {name}
            </Hit>
          ))}
        </nav>
      )}
      <div className="flex min-w-0 flex-1 flex-col">
        <div className="flex h-[38px] shrink-0 items-center gap-2 border-b border-os-line px-3">
          <button
            type="button"
            aria-label="Back"
            onClick={() => act((x) => keyPress(x, 'cmd+['))}
            disabled={!f.back.length}
            className="grid size-7 place-items-center rounded-sm text-os-text-2 hover:bg-os-hover disabled:opacity-40"
          >
            <Icon d={Glyph.back} className="size-3.5" />
          </button>
          <span className="flex-1" />
          <span
            className={`flex h-[26px] w-[180px] items-center gap-2 rounded-sm bg-os-chrome px-2 text-os-text-2 ${d.focus === 'search' ? 'outline-2 outline-os-text-2' : ''}`}
          >
            <Icon d={Glyph.search} className="size-3" />
            <span className={f.search ? 'text-os-text' : ''}>{f.search || 'Search'}</span>
            {d.focus === 'search' && <Caret />}
          </span>
        </div>
        <div className="grid flex-1 auto-rows-min grid-cols-[repeat(auto-fill,minmax(92px,1fr))] gap-2 overflow-auto p-4">
          {FINDER[f.folder]
            .filter((x) => x.name.toLowerCase().includes(q))
            .map((x) => (
              <Hit
                key={x.name}
                w="Finder"
                k={`file:${x.name}`}
                press={press}
                className="flex flex-col items-center gap-1.5 rounded-md p-2 text-center hover:bg-os-hover"
              >
                {x.open && !(FOLDERS as readonly string[]).includes(x.open) ? (
                  <AppIcon app={x.open as App} className="size-12" />
                ) : (
                  <Icon
                    d={x.open ? Glyph.folder : Glyph.file}
                    className={`size-12 ${x.open ? 'fill-os-select text-os-text-2' : 'text-os-text-2'}`}
                  />
                )}
                <span className="line-clamp-2 break-all text-[12px] leading-tight">{x.name}</span>
              </Hit>
            ))}
        </div>
      </div>
    </div>
  );
}

/** A little colour for code: strings, comments and numbers, enough to read as code. */
function CodeLine({ line }: { line: string }) {
  const parts = line.split(/("(?:[^"\\]|\\.)*"|\/\/.*$|\b\d+(?:\.\d+)?\b)/);
  return (
    <>
      {parts.map((s, i) =>
        s.startsWith('"') ? (
          <span
            key={i}
            className={
              parts[i + 1]?.trimStart().startsWith(':') ? 'text-code-key' : 'text-code-str'
            }
          >
            {s}
          </span>
        ) : s.startsWith('//') ? (
          <span key={i} className="text-os-text-2">
            {s}
          </span>
        ) : /^\d/.test(s) ? (
          <span key={i} className="text-code-num">
            {s}
          </span>
        ) : (
          s
        ),
      )}
    </>
  );
}

export function CodeTitle({ d }: Ctx) {
  return <Title>{d.code.file} — nohandspilot</Title>;
}

export function CodeBody({ d, press }: Ctx) {
  const ref = useScrollTo(d.scroll['Visual Studio Code'] ?? 0);
  const lines = FILES[d.code.file].split('\n');
  return (
    <div className="flex h-full">
      <div className="flex w-[44px] shrink-0 flex-col items-center gap-2 bg-os-chrome py-2">
        <Hit
          w="Visual Studio Code"
          k="Explorer"
          press={press}
          label="Explorer"
          className={`grid size-9 place-items-center rounded-sm ${d.code.sidebar ? 'text-os-text' : 'text-os-text-2'} hover:bg-os-hover`}
        >
          <Icon d={Glyph.files} className="size-5" />
        </Hit>
        <span aria-hidden className="grid size-9 place-items-center text-os-text-2">
          <Icon d={Glyph.search} className="size-5" />
        </span>
      </div>
      {d.code.sidebar && (
        <div className="w-[180px] shrink-0 bg-os-sidebar py-2">
          <p className="px-4 pb-2 text-[11px] font-semibold tracking-wide text-os-text-2">
            EXPLORER
          </p>
          <p className="px-4 pb-1 text-[11px] font-bold">NOHANDSPILOT</p>
          {Object.keys(FILES).map((f) => (
            <Hit
              key={f}
              w="Visual Studio Code"
              k={`file:${f}`}
              press={press}
              className={`flex w-full items-center gap-2 px-5 py-[3px] ${f === d.code.file ? 'bg-os-select' : 'hover:bg-os-hover'}`}
            >
              <Icon d={Glyph.file} className="size-3.5 text-os-text-2" />
              {f}
            </Hit>
          ))}
        </div>
      )}
      <div className="flex min-w-0 flex-1 flex-col">
        <div className="flex h-[32px] shrink-0 items-end bg-os-chrome">
          <span className="flex h-full items-center border-t-2 border-os-text-2 bg-os-window px-4">
            {d.code.file}
          </span>
        </div>
        <div
          ref={ref}
          className="min-h-0 flex-1 overflow-auto py-2 font-mono text-[12px] leading-[18px]"
        >
          {lines.map((line, i) => (
            <div key={i} className="flex whitespace-pre">
              <span className="w-12 shrink-0 select-none pr-4 text-right text-os-text-2">
                {i + 1}
              </span>
              <span>
                <CodeLine line={line} />
              </span>
            </div>
          ))}
        </div>
        {d.code.terminal && (
          <div className="h-[36%] shrink-0 border-t border-os-line px-4 py-2 font-mono text-[12px]">
            <p className="mb-2 font-os text-[11px] font-semibold tracking-wide text-os-text-2">
              TERMINAL
            </p>
            <p>
              ~/nohandspilot % <Caret />
            </p>
          </div>
        )}
      </div>
    </div>
  );
}

export function ClaudeBody({ d, press }: Ctx) {
  const c = d.claude;
  const ref = useScrollTo(0);
  const typing = d.focus === 'composer';
  return (
    <div className="flex h-full">
      {c.sidebar && (
        <aside className="w-[190px] shrink-0 space-y-1 bg-os-sidebar p-2">
          <Hit
            w="Claude"
            k="New chat"
            press={press}
            className="flex w-full items-center gap-2 rounded-sm px-2 py-1.5 font-medium hover:bg-os-hover"
          >
            <Icon d={Glyph.plus} className="size-3.5" />
            New chat
          </Hit>
          <p className="px-2 pb-1 pt-3 text-[11px] font-semibold text-os-text-2">Recents</p>
          {CHATS.map((chat) => (
            <Hit
              key={chat}
              w="Claude"
              k={`chat:${chat}`}
              press={press}
              className="block w-full truncate rounded-sm px-2 py-1.5 hover:bg-os-hover"
            >
              {chat}
            </Hit>
          ))}
        </aside>
      )}
      <div className="flex min-w-0 flex-1 flex-col">
        <div ref={ref} className="min-h-0 flex-1 space-y-4 overflow-auto p-6">
          {c.messages.length ? (
            c.messages.map((m, i) => (
              <div key={i} className="space-y-3">
                <p className="ml-auto w-fit max-w-[80%] rounded-lg bg-os-select px-4 py-2">{m}</p>
                <p className="text-os-text-2 italic">On your Mac, Claude answers here.</p>
              </div>
            ))
          ) : (
            <p className="grid h-full place-items-center text-[20px] text-os-text-2">
              Start a new chat
            </p>
          )}
        </div>
        <div
          className={`m-4 mt-0 flex min-h-[64px] items-start gap-2 rounded-lg border bg-os-field p-3 ${typing ? 'border-os-text-2' : 'border-os-line'}`}
        >
          <p className="flex-1">
            {c.draft || (typing ? '' : <span className="text-os-text-2">Write a message</span>)}
            {typing && <Caret />}
          </p>
          {c.draft.trim() && (
            <Hit
              w="Claude"
              k="Send"
              press={press}
              label="Send"
              className="grid size-7 place-items-center rounded-sm bg-os-text text-os-window"
            >
              <Icon d={Glyph.send} className="size-3.5" />
            </Hit>
          )}
        </div>
      </div>
    </div>
  );
}

export function TerminalBody({ d }: Ctx) {
  return (
    <div className="h-full overflow-auto bg-os-field p-3 font-mono text-[12px] leading-[18px]">
      {d.terminal.lines.map((l, i) => (
        <p key={i}>~ % {l}</p>
      ))}
      <p>
        ~ % {d.terminal.draft}
        <Caret />
      </p>
    </div>
  );
}

const stationHue = (s: string) => (STATIONS.indexOf(s) * 53 + 330) % 360;

export function MusicBody({ d, press }: Ctx) {
  const m = d.music;
  return (
    <div className="flex h-full flex-col">
      {m.station && (
        <div className="flex h-[58px] shrink-0 items-center gap-3 border-b border-os-line px-4">
          <span
            aria-hidden
            className="size-9 rounded-sm"
            style={{
              background: `linear-gradient(135deg, hsl(${stationHue(m.station)} 45% 50%), hsl(${stationHue(m.station) + 50} 40% 25%))`,
            }}
          />
          <div className="min-w-0 flex-1">
            <p className="font-semibold">{m.station}</p>
            <p className="text-[12px] text-os-text-2">
              Station · {m.playing ? 'Playing' : 'Paused'}
            </p>
          </div>
          <Hit
            w="Music"
            k="player"
            press={press}
            label={m.playing ? 'Pause' : 'Play'}
            className="grid size-8 place-items-center rounded-full hover:bg-os-hover"
          >
            <Icon d={m.playing ? Glyph.pause : Glyph.play} className="size-4" />
          </Hit>
        </div>
      )}
      <div className="min-h-0 flex-1 overflow-auto p-5">
        {m.search && (
          <p className="mb-5 rounded-sm border border-os-line px-3 py-2 text-os-text-2">
            Searched for “{m.search}”. On your Mac, Music shows the real results.
          </p>
        )}
        <p className="mb-3 text-[17px] font-bold">Moods</p>
        <div className="grid grid-cols-3 gap-3">
          {STATIONS.map((s) => (
            <Hit key={s} w="Music" k={`station:${s}`} press={press} className="group">
              <span
                aria-hidden
                className="block aspect-square rounded-md"
                style={{
                  background: `linear-gradient(135deg, hsl(${stationHue(s)} 45% 52%), hsl(${stationHue(s) + 50} 40% 24%))`,
                }}
              />
              <span className={`mt-1.5 block font-medium ${s === m.station ? 'underline' : ''}`}>
                {s}
              </span>
            </Hit>
          ))}
        </div>
      </div>
    </div>
  );
}

export function SettingsBody({ d, press }: Ctx) {
  const pane = d.settings.pane;
  return (
    <div className="flex h-full">
      <nav
        aria-label="Settings"
        className="w-[200px] shrink-0 space-y-0.5 overflow-auto bg-os-sidebar p-2"
      >
        {Object.values(PANES).map((p) => (
          <Hit
            key={p}
            w="System Settings"
            k={p}
            press={press}
            className={`flex w-full items-center gap-2 rounded-sm px-2 py-1 ${p === pane ? 'bg-os-select' : 'hover:bg-os-hover'}`}
          >
            <span
              aria-hidden
              className="grid size-5 place-items-center rounded-[5px] bg-os-control text-[10px] font-bold"
            >
              {p.charAt(0)}
            </span>
            {p}
          </Hit>
        ))}
      </nav>
      <div className="flex-1 p-6">
        <p className="text-[20px] font-bold">{pane}</p>
        <div className="mt-4 rounded-md bg-os-chrome px-4 py-3 text-os-text-2">
          On your Mac, this is the real {pane} pane, opened straight from its settings link.
        </div>
      </div>
    </div>
  );
}

// MARK: NoHandsPilot

const STEPS: ReactNode[] = [
  <>
    <b>Download</b> the zip from the latest release, unzip it, and move Pilot to your Applications
    folder.
  </>,
  <>
    <b>Open it once.</b> It isn't notarized by Apple, so macOS stops the first launch: open System
    Settings → Privacy &amp; Security, scroll down and click <b>Open Anyway</b>. (On macOS 14 and
    earlier, right-click Pilot → Open → Open.)
  </>,
  <>
    <b>Accessibility.</b> When macOS says “Pilot would like to control this computer”, click Open
    System Settings and turn Pilot on under Privacy &amp; Security → Accessibility. Within about 2
    seconds Pilot’s menu says it’s catching “Pilot, …” from Wispr. If it doesn’t, quit Pilot from
    its menu and open it again; if it still doesn’t, also add Pilot under Privacy &amp; Security →{' '}
    <b>Input Monitoring</b>.
  </>,
  <>
    <b>Wispr Flow → Dictionary:</b> add “Pilot”, so it’s never heard as “Pilate”.
  </>,
  <>
    <b>Try it.</b> Press Control-Option-P, type{' '}
    <code className="font-mono">open chrome, new tab, search for docker networking</code> and press
    Return. Then hold your Wispr key anywhere and say “Pilot, open Finder”.
  </>,
  <>
    <b>No hands.</b> Start Wispr Flow’s own hands-free mode and say “Pilot, …” as usual. Pilot never
    opens your microphone. Wispr Flow is the only thing that listens.
  </>,
];

export function PilotBody({ d, press }: Ctx) {
  const ref = useScrollTo(d.scroll.NoHandsPilot ?? 0);
  return (
    <div ref={ref} className="h-full overflow-auto p-6">
      <div className="flex items-center gap-4">
        <AppIcon app="NoHandsPilot" className="size-14" />
        <div>
          <p className="text-[20px] font-bold">No Hands Pilot</p>
          <p className="text-os-text-2">
            Say “Pilot, …” with Wispr Flow and your Mac does it. A menu-bar app for macOS 13 or
            later.
          </p>
        </div>
      </div>
      <div className="mt-5 flex flex-wrap gap-2">
        <Hit
          w="NoHandsPilot"
          k="download"
          press={press}
          className="rounded-sm bg-os-text px-4 py-2 font-semibold text-os-window"
        >
          Download for Mac
        </Hit>
        <Hit
          w="NoHandsPilot"
          k="github"
          press={press}
          className="rounded-sm border border-os-line px-4 py-2 font-semibold hover:bg-os-hover"
        >
          View on GitHub ↗
        </Hit>
      </div>
      <p className="mt-6 text-[11px] font-semibold uppercase tracking-wide text-os-text-2">
        Set up, about 10 minutes
      </p>
      <ol className="mt-2 space-y-3">
        {STEPS.map((s, i) => (
          <li key={i} className="grid grid-cols-[22px_1fr] gap-2 leading-relaxed">
            <span className="grid size-[20px] place-items-center rounded-full bg-os-chrome text-[11px] font-semibold">
              {i + 1}
            </span>
            <span>{s}</span>
          </li>
        ))}
      </ol>
      <Hit
        w="NoHandsPilot"
        k="source"
        press={press}
        className="mt-5 flex items-center gap-2 font-semibold"
      >
        <span
          aria-hidden
          className={`inline-block transition ${d.pilot.source ? 'rotate-90' : ''}`}
        >
          ▸
        </span>
        Build from source
      </Hit>
      {d.pilot.source && (
        <div className="mt-2 space-y-2 rounded-md bg-os-chrome p-4">
          <p>
            Needs macOS 13 or later and the Xcode Command Line Tools (full Xcode isn’t required).
          </p>
          <pre className="overflow-x-auto font-mono text-[12px] leading-relaxed">{`git clone https://github.com/jsuryacodes/nohandspilot
cd nohandspilot
app/build.sh                    # builds, signs, installs to ~/Applications, opens it
cd app && swift run BrainCheck  # the matching self-checks`}</pre>
        </div>
      )}
      <p className="mt-6 text-[12px] text-os-text-2">
        Releases: <span className="font-mono">{RELEASES_URL.replace('https://', '')}</span>
      </p>
    </div>
  );
}

/** Pilot's "What can I say?" window: every phrase in commands.json, by app, with a filter. */
export function HelpBody({ d, run }: Ctx) {
  const [query, setQuery] = useState('');
  const ref = useScrollTo(d.scroll.Help ?? 0);
  const q = query.trim().toLowerCase();
  const groups = HELP.map((g) => ({
    ...g,
    rows: g.rows.filter(
      (r) =>
        !q ||
        g.title.toLowerCase().includes(q) ||
        r.phrases.some((ph) => ph.toLowerCase().includes(q)),
    ),
  })).filter((g) => g.rows.length);
  return (
    <div className="flex h-full flex-col">
      <div className="border-b border-os-line p-3">
        <input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search phrases"
          aria-label="Search phrases"
          className="w-full rounded-sm bg-os-chrome px-3 py-1.5 outline-none placeholder:text-os-text-2 focus:outline-2 focus:outline-os-text-2"
        />
      </div>
      <div ref={ref} className="min-h-0 flex-1 overflow-auto p-5">
        <p className="text-os-text-2">
          Start with “Pilot” when dictating with Wispr (not needed in the command bar). Chain with
          commas: “Pilot, open Chrome, new tab, search for cats”. Add “in &lt;app&gt;” to run a
          command in another app. Phrases without a slot run when you click them.
        </p>
        {!groups.length && <p className="mt-5 text-os-text-2">No phrase has “{query}”.</p>}
        {groups.map((g) => (
          <section key={g.title} className="mt-5">
            <p className="mb-2 text-[11px] font-semibold uppercase tracking-wide text-os-text-2">
              {g.title}
            </p>
            <ul className="space-y-1.5">
              {g.rows.map((r, i) => (
                <li key={i} className="flex flex-wrap items-baseline gap-x-2 gap-y-1">
                  {r.phrases.map((ph) =>
                    ph.includes('{') ? (
                      <span
                        key={ph}
                        className="rounded-[4px] border border-dashed border-os-line px-1.5 font-mono text-[12px] text-os-text-2"
                      >
                        {ph}
                      </span>
                    ) : (
                      <button
                        key={ph}
                        type="button"
                        onClick={() => run(ph)}
                        className="rounded-[4px] bg-os-chrome px-1.5 font-mono text-[12px] hover:bg-os-select"
                      >
                        {ph}
                      </button>
                    ),
                  )}
                  {r.note && <span className="text-[12px] text-os-text-2">({r.note})</span>}
                </li>
              ))}
            </ul>
          </section>
        ))}
      </div>
    </div>
  );
}
