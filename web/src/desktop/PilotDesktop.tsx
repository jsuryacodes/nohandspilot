import { AnimatePresence, MotionConfig, useInView, useReducedMotion } from 'framer-motion';
import {
  useCallback,
  useEffect,
  useEffectEvent,
  useId,
  useLayoutEffect,
  useRef,
  useState,
  type ReactNode,
} from 'react';
import type { Action, Step } from '../brain/brain';
import { hud as hudText, plan as planText, type App } from '../brain/site';
import * as apps from './apps';
import { CommandBar, type Phase } from './CommandBar';
import { Dock } from './Dock';
import { Hud, type HudLine, type HudState } from './Hud';
import { MenuBar } from './MenuBar';
import {
  activate,
  appOf,
  badged,
  closeWindow,
  focusWindow,
  frontWindow,
  initial,
  isShown,
  minimise,
  press,
  runStep,
  toggleFull,
  type Desk,
  type Win,
} from './sim';
import { Window, type Rect } from './Window';

/** The suggestions, in order: each one sets up the next. "pause the video" comes after "click 3", because "play …
 *  on YouTube" opens the search results (as on a Mac), and the video only plays once you click one. */
export const CHIPS = [
  'open Chrome',
  'new tab',
  'search for Docker networking',
  'open Chrome, new tab, search for Docker networking',
  'play lofi beats on YouTube',
  'show numbers',
  'click 3',
  'pause the video',
  'switch back',
  'study mode',
  'open NoHandsPilot',
  'what can I say?',
];

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const MENU = 24;
// Where each window opens, as fractions of the space between the menu bar and the Dock: x, y, width, height
const SPOTS: Record<Win, [number, number, number, number]> = {
  'Google Chrome': [0.05, 0.02, 0.62, 0.96],
  'Visual Studio Code': [0.2, 0.05, 0.64, 0.92],
  Claude: [0.34, 0.03, 0.52, 0.94],
  Terminal: [0.08, 0.46, 0.46, 0.52],
  Finder: [0.14, 0.1, 0.54, 0.74],
  Music: [0.4, 0.07, 0.5, 0.86],
  'System Settings': [0.28, 0.06, 0.48, 0.86],
  NoHandsPilot: [0.31, 0.02, 0.44, 0.97],
  Help: [0.58, 0.02, 0.38, 0.97],
};

function rectFor(w: Win, width: number, height: number, bottom: number): Rect {
  const [fx, fy, fw, fh] = SPOTS[w];
  const top = MENU + 10;
  const area = { w: width - 24, h: Math.max(320, height - top - bottom) };
  const r = { w: Math.max(440, fw * area.w), h: Math.max(300, fh * area.h) };
  return { x: Math.min(12 + fx * area.w, width - r.w - 8), y: top + fy * area.h, ...r };
}

/** How long a step's actions take to show, so a chain plays out where you can follow it. */
const pause = (a: Action) =>
  ({ openApp: 420, openURL: 460, keys: 200, type: 140, scroll: 380, click: 300, numbers: 220 })[
    a.kind as string
  ] ?? (a.kind === 'wait' ? Math.min(a.ms, 260) : 200);

const TITLES: Partial<Record<Win, string>> = {
  Claude: 'Claude',
  Terminal: 'Terminal — zsh',
  Music: 'Music',
  'System Settings': 'System Settings',
  NoHandsPilot: 'No Hands Pilot',
  Help: 'What can I say?',
};

/** A Mac in the browser, running commands through Pilot's real Brain. `compact` is the landing page's version:
 *  a scaled-down screen with the command bar below it. */
export function PilotDesktop({
  compact = false,
  autoplay = [],
  loop = false,
}: {
  compact?: boolean;
  autoplay?: string[];
  loop?: boolean;
}) {
  const [desk, setDesk] = useState(initial);
  const deskRef = useRef(desk);
  const [hud, setHud] = useState<HudState>();
  const [text, setText] = useState('');
  const [phase, setPhase] = useState<Phase>('ready');
  const [chip, setChip] = useState(0);
  const [count, setCount] = useState(0);
  const [visitor, setVisitor] = useState(false); // someone took over: no more auto-play, and the HUD speaks up
  const [size, setSize] = useState({ width: 0, height: 0 });
  const [spots, setSpots] = useState<{ n: number; x: number; y: number }[]>([]);
  const root = useRef<HTMLDivElement>(null);
  const stage = useRef<HTMLDivElement>(null);
  const input = useRef<HTMLInputElement>(null);
  const queue = useRef(Promise.resolve());
  const hideHud = useRef<number>(undefined);
  const reduce = useReducedMotion() ?? false;
  const wallpaper = useId();

  const apply = useCallback((d: Desk) => {
    deskRef.current = d;
    setDesk(d);
  }, []);
  const act = useCallback((change: (d: Desk) => Desk) => apply(change(deskRef.current)), [apply]);

  useLayoutEffect(() => {
    const el = root.current;
    if (!el) return;
    const ro = new ResizeObserver(([e]) =>
      setSize({ width: e.contentRect.width, height: e.contentRect.height }),
    );
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  // A real-size Mac when there's room (/try on a laptop); otherwise a scaled one, with the controls below it.
  const inside = !compact && size.width >= 900;
  const W = inside ? size.width : compact ? 1040 : 1024;
  const H = inside ? Math.max(560, size.height) : compact ? 650 : 680;
  const scale = inside ? 1 : Math.min(1, size.width / W) || 1;
  const bottom = inside ? 220 : 92;
  const overlay = inside || (compact && size.width >= 600); // the HUD over the screen, where there's room
  // Drawn this small it's a picture of a Mac: its buttons would be specks. The full-size chips and command bar drive
  // it, and the hero's links to the full-size one.
  const picture = scale < 0.75;

  /** Plays a step's actions one at a time (typing shows up letter by letter), then lands on the real result. */
  const playStep = async (before: Desk, step: Step) => {
    const actions = step.actions;
    for (let j = 0; j < actions.length; j++) {
      const a = actions[j];
      if (a.kind === 'type' && !reduce) {
        for (let k = 1; k < a.text.length; k += 2) {
          apply(
            runStep(before, {
              ...step,
              actions: [...actions.slice(0, j), { kind: 'type', text: a.text.slice(0, k) }],
            }).desk,
          );
          await sleep(22);
        }
      }
      apply(runStep(before, { ...step, actions: actions.slice(0, j + 1) }).desk);
      await sleep(reduce ? 60 : pause(a));
    }
  };

  const execute = async (command: string) => {
    const said = command.trim();
    if (!said) return;
    window.clearTimeout(hideHud.current);
    const { plan, ms } = planText(said, deskRef.current.front);
    setCount((c) => c + 1);
    const asked = CHIPS.findIndex(
      (c) => c.toLowerCase() === said.toLowerCase().replace(/^pilot,?\s*/, ''),
    );
    if (asked >= 0) setChip((asked + 1) % CHIPS.length); // the suggestions move on past what you just did
    if (plan.kind !== 'run') {
      setHud({ id: Date.now(), lines: [], ms, miss: hudText(plan, ms).text });
      setPhase('ready');
    } else {
      const lines: HudLine[] = plan.steps.map((s) => ({ text: s.say, kind: 'pending' }));
      const hudId = Date.now();
      const show = () => setHud({ id: hudId, lines: [...lines], ms });
      setPhase('acting');
      for (const [i, step] of plan.steps.entries()) {
        lines[i] = { ...lines[i], kind: 'active' };
        show();
        const before = deskRef.current;
        const r = runStep(before, step);
        if (r.kind === 'done') await playStep(before, step);
        apply(r.desk);
        lines[i] = { text: r.line, kind: r.kind, link: r.link };
        show();
        if (r.kind === 'error') break;
        if (r.kind !== 'done') await sleep(reduce ? 60 : 260);
      }
      setPhase('ready');
      // Pilot shows no toast for "what can I say?": its window is the answer (main.swift)
      if (plan.steps.every((st) => st.actions.every((a) => a.kind === 'help'))) setHud(undefined);
    }
    hideHud.current = window.setTimeout(() => setHud(undefined), 4200);
  };
  /** Commands run one after another, never on top of each other. */
  const enqueue = (command: string) => (queue.current = queue.current.then(() => execute(command)));
  const run = (command: string) => {
    setText(command);
    enqueue(command).then(() => setText((t) => (t === command ? '' : t)));
  };

  const takeOver = () => {
    if (!visitor) setVisitor(true);
  };

  const autoRun = useEffectEvent(async (cancelled: () => boolean) => {
    for (let i = 0; !cancelled(); i++) {
      if (i === autoplay.length) {
        if (!loop) return;
        i = 0;
        await sleep(1200);
      }
      if (loop && i === 0 && deskRef.current !== initial) {
        apply(initial); // each round starts from an empty desktop
        setHud(undefined);
        await sleep(700);
        if (cancelled()) return;
      }
      const command = autoplay[i];
      setPhase('hearing');
      for (let n = 1; n <= command.length && !cancelled(); n++) {
        setText(command.slice(0, n));
        await sleep(reduce ? 0 : 28);
      }
      if (cancelled()) return setText('');
      await enqueue(command);
      setText('');
      await sleep(2000);
    }
  });
  // Plays only while it's on screen, so a page scrolled past it isn't doing work.
  const seen = useInView(root, { amount: 0.25 });
  useEffect(() => {
    if (visitor || !autoplay.length || !seen) return;
    let stop = false;
    const start = window.setTimeout(() => autoRun(() => stop), 650); // an empty desktop first, then it starts
    return () => {
      stop = true;
      window.clearTimeout(start);
    };
  }, [visitor, autoplay.length, seen]);

  // "/" starts typing a command, from anywhere on the page
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const t = e.target as HTMLElement;
      if (
        e.key !== '/' ||
        e.metaKey ||
        e.ctrlKey ||
        t.closest('input, textarea, [contenteditable]')
      )
        return;
      e.preventDefault();
      input.current?.focus();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  // Numbers: a badge on the top-left corner of everything clickable in the front window. They go after 20 s.
  const front = frontWindow(desk);
  useEffect(() => {
    if (!desk.numbers || !front) return;
    const measure = window.setTimeout(
      () => {
        const box = stage.current?.getBoundingClientRect();
        if (!box) return;
        setSpots(
          badged(deskRef.current, front).flatMap((c, i) => {
            const el = stage.current?.querySelector(`[data-click="${CSS.escape(c.id)}"]`);
            const r = el?.getBoundingClientRect();
            // only what's on screen gets a badge: inside its window, not scrolled out of view
            const win = el?.closest('section')?.getBoundingClientRect();
            const seen =
              r && win && r.width && r.top >= win.top && r.top < win.bottom && r.left < win.right;
            return seen
              ? [{ n: i + 1, x: (r.left - box.left) / scale, y: (r.top - box.top) / scale }]
              : [];
          }),
        );
      },
      reduce ? 0 : 340,
    );
    const hide = window.setTimeout(() => act((d) => ({ ...d, numbers: false })), 20_000);
    return () => {
      window.clearTimeout(measure);
      window.clearTimeout(hide);
    };
  }, [desk.numbers, front, desk.chrome.active, scale, reduce, act]);

  const mousePress = (id: string) => {
    takeOver();
    const r = press(deskRef.current, id);
    apply(r.desk);
    if (r.link) window.open(r.link, '_blank', 'noopener,noreferrer'); // a real click, so no pop-up blocker
  };
  const ctx = { d: desk, press: mousePress, act, run };
  const bodies: Record<Win, () => ReactNode> = {
    'Google Chrome': () => <apps.ChromeBody {...ctx} />,
    Finder: () => <apps.FinderBody {...ctx} />,
    'Visual Studio Code': () => <apps.CodeBody {...ctx} />,
    Claude: () => <apps.ClaudeBody {...ctx} />,
    Terminal: () => <apps.TerminalBody {...ctx} />,
    Music: () => <apps.MusicBody {...ctx} />,
    'System Settings': () => <apps.SettingsBody {...ctx} />,
    NoHandsPilot: () => <apps.PilotBody {...ctx} />,
    Help: () => <apps.HelpBody {...ctx} />,
  };
  const title = (w: Win) =>
    w === 'Google Chrome' ? (
      <apps.ChromeTabs {...ctx} />
    ) : w === 'Finder' ? (
      <apps.FinderTitle {...ctx} />
    ) : w === 'Visual Studio Code' ? (
      <apps.CodeTitle {...ctx} />
    ) : (
      <apps.PlainTitle text={TITLES[w] ?? w} />
    );
  const fullFront = !!desk.full && front === desk.full;

  const controls = (
    <CommandBar
      value={text}
      onChange={(t) => {
        takeOver();
        setText(t);
      }}
      onRun={(t) => {
        takeOver();
        run(t);
      }}
      phase={phase}
      onHearing={(on) => setPhase(on ? 'hearing' : 'ready')}
      chips={[0, 1, 2].map((k) => ({
        index: (chip + k) % CHIPS.length,
        text: CHIPS[(chip + k) % CHIPS.length],
      }))}
      onChip={(i) => {
        takeOver();
        run(CHIPS[i]);
      }}
      input={input}
    />
  );

  return (
    <div
      ref={root}
      onPointerDownCapture={takeOver}
      onKeyDownCapture={(e) => e.key !== 'Tab' && takeOver()}
      className={inside ? 'relative h-full w-full overflow-hidden' : 'w-full'}
      style={{ visibility: size.width ? undefined : 'hidden' }}
    >
      <div
        className={`relative overflow-hidden ${inside ? 'h-full' : 'rounded-xl border border-line shadow-window'}`}
        style={inside ? undefined : { height: H * scale }}
        role="region"
        aria-label="A Mac running Pilot"
      >
        <MotionConfig transformPagePoint={(p) => ({ x: p.x / scale, y: p.y / scale })}>
          <div
            ref={stage}
            inert={picture}
            className="absolute left-0 top-0 origin-top-left select-none overflow-hidden"
            style={{ width: W, height: H, transform: `scale(${scale})` }}
          >
            <Wallpaper
              id={wallpaper}
              onClick={() =>
                act((d) => ({ ...d, front: 'Finder', focus: undefined, numbers: false }))
              }
            />
            <MenuBar front={desk.front} count={count} onHelp={() => run('what can I say?')} />
            <AnimatePresence>
              {desk.windows.map((w, z) => (
                <Window
                  key={w}
                  label={w === 'Help' ? 'What can I say?' : w}
                  title={title(w)}
                  active={w === front}
                  z={10 + z}
                  rect={rectFor(w, W, H, bottom)}
                  full={desk.full === w ? { x: 0, y: MENU, w: W, h: H - MENU } : undefined}
                  minimised={desk.minimised.includes(w)}
                  hidden={!isShown(desk, w) && !desk.minimised.includes(w)}
                  stage={stage}
                  stageHeight={H}
                  onFocus={() => w !== front && act((d) => focusWindow(d, w))}
                  onClose={() => act((d) => closeWindow(d, w))}
                  onMinimise={() => act((d) => minimise(d, w))}
                  onFull={() => act((d) => toggleFull(d, w))}
                >
                  {bodies[w]()}
                </Window>
              ))}
            </AnimatePresence>
            {desk.numbers &&
              spots.map((s) => (
                <span
                  key={s.n}
                  aria-hidden
                  className="pointer-events-none absolute z-[950] rounded-[5px] bg-signal px-1 font-mono text-[11px] font-bold leading-[16px] text-canvas shadow-hud"
                  style={{ left: s.x - 4, top: s.y - 4 }}
                >
                  {s.n}
                </span>
              ))}
            <Dock
              running={desk.running}
              scale={scale}
              hidden={fullFront}
              onOpen={(app: App) =>
                act((d) => (appOf(app) === d.front && frontWindow(d) ? d : activate(d, app)))
              }
            />
          </div>
        </MotionConfig>
        {picture && compact && (
          <a
            href="/try"
            className="group absolute inset-0 z-[1050] rounded-xl"
            aria-label="Open the Mac full size"
          >
            <span className="absolute right-3 top-6 rounded-full bg-raised px-3 py-1 text-micro text-fg opacity-0 shadow-hud transition group-hover:opacity-100 group-focus-visible:opacity-100">
              Open it full size ↗
            </span>
          </a>
        )}
        {overlay && (
          // Over the screen, above the Dock (above the command bar on a full-size Mac)
          <div
            className="pointer-events-none absolute inset-x-0 z-[1100]"
            style={{ bottom: inside ? 236 : 92 * scale + 8 }}
          >
            <Hud hud={hud} announce={visitor} />
          </div>
        )}
        {inside && (
          <>
            <div className="absolute inset-x-0 bottom-[86px] z-[1100] flex justify-center px-4">
              {controls}
            </div>
          </>
        )}
      </div>
      {!inside && (
        <>
          {/* On a small screen the HUD sits under the Mac instead of covering it; its space is kept so nothing jumps. */}
          {!overlay && (
            <div className="mt-3 min-h-[5.75rem]">
              <Hud hud={hud} announce={visitor} />
            </div>
          )}
          <div className="mt-4 flex justify-center">{controls}</div>
        </>
      )}
      {!inside && !compact && (
        <p className="mt-4 text-center text-micro text-fg-3">
          This is the small version. On a laptop, the Mac fills the screen.
        </p>
      )}
    </div>
  );
}

/** Dunes under a big sky, drawn here so the wallpaper follows the theme (night, or morning in light mode). */
function Wallpaper({ id, onClick }: { id: string; onClick: () => void }) {
  const dune = (n: number) => ({ fill: `url(#${id}d${n})` });
  return (
    <svg
      viewBox="0 0 1600 1000"
      preserveAspectRatio="xMidYMid slice"
      aria-hidden
      className="absolute inset-0 size-full"
      onPointerDown={onClick}
    >
      <defs>
        <linearGradient id={`${id}sky`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" style={{ stopColor: 'var(--wp-sky-1)' }} />
          <stop offset=".6" style={{ stopColor: 'var(--wp-sky-2)' }} />
          <stop offset="1" style={{ stopColor: 'var(--wp-sky-3)' }} />
        </linearGradient>
        {[1, 2, 3].map((n) => (
          <linearGradient key={n} id={`${id}d${n}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" style={{ stopColor: `var(--wp-dune-${n})` }} />
            <stop offset="1" style={{ stopColor: 'var(--wp-dune-3)' }} />
          </linearGradient>
        ))}
        <radialGradient id={`${id}sun`}>
          <stop offset="0" style={{ stopColor: 'var(--wp-sun)', stopOpacity: 0.9 }} />
          <stop offset="1" style={{ stopColor: 'var(--wp-sun)', stopOpacity: 0 }} />
        </radialGradient>
      </defs>
      <rect width="1600" height="1000" fill={`url(#${id}sky)`} />
      <circle cx="1150" cy="560" r="190" fill={`url(#${id}sun)`} opacity=".55" />
      <circle cx="1150" cy="560" r="34" style={{ fill: 'var(--wp-sun)' }} opacity=".9" />
      <path d="M0 640C220 600 420 585 640 610s420 60 620 20 270-40 340-30v360H0Z" style={dune(1)} />
      <path
        d="M0 640C220 600 420 585 640 610s420 60 620 20 270-40 340-30"
        fill="none"
        style={{ stroke: 'var(--wp-edge)' }}
        strokeWidth="2"
      />
      <path d="M0 760c200-70 460-60 700-20s520 30 900-40v300H0Z" style={dune(2)} />
      <path
        d="M0 760c200-70 460-60 700-20s520 30 900-40"
        fill="none"
        style={{ stroke: 'var(--wp-edge)' }}
        strokeWidth="2"
      />
      <path d="M0 880c300-40 600-80 920-30s480 20 680-10v160H0Z" style={dune(3)} />
    </svg>
  );
}
