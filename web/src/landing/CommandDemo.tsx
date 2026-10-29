import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { useEffect, useRef, useState } from 'react';
import type { Action } from '../brain/brain';
import { hud, keysLabel, plan } from '../brain/site';
import { base, easeOut } from '../motion';

const SCRIPT = [
  'open Chrome, new tab, search for Docker networking',
  'play lofi beats on YouTube',
  'pause the video',
  'show numbers',
  'click 3',
  'switch back',
  'study mode',
];
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const STEP_S = 0.14; // one step of a plan appearing, as the Mac would do it

type Phase = 'ready' | 'hearing' | 'acting';
const STATUS: Record<Phase, string> = { ready: 'ready', hearing: 'hearing you', acting: 'acting' };

/** One action as Pilot's Hands would do it on a Mac. */
function actionLabel(a: Action): string {
  switch (a.kind) {
    case 'openApp':
      return `open ${a.app}`;
    case 'keys':
      return keysLabel(a.keys);
    case 'type':
      return `type "${a.text}"`;
    case 'openURL':
      return `open ${a.url.replace(/^https:\/\/(www\.)?/, '')}`;
    case 'media':
      return `${a.key} the player`;
    case 'scroll':
      return `scroll ${a.direction}`;
    case 'click':
      return /^\d+$/.test(a.target) ? `press badge ${a.target}` : `press "${a.target}"`;
    case 'numbers':
      return a.show ? 'badge everything clickable' : 'clear the badges';
    case 'previousApp':
      return 'back to the last app';
    case 'wait':
      return `wait ${a.ms} ms`;
    default:
      return a.kind;
  }
}

/** A command said to Pilot, what it matched, and what the Mac would do. Types its own until you type. */
export function CommandDemo() {
  const [text, setText] = useState('');
  const [result, setResult] = useState<ReturnType<typeof plan>>();
  const [phase, setPhase] = useState<Phase>('ready');
  const [yours, setYours] = useState(false); // you've typed: stop the show, announce results
  const reduce = useReducedMotion();
  const input = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (yours) return;
    let stop = false;
    (async () => {
      for (let i = 0; !stop; i = (i + 1) % SCRIPT.length) {
        const line = `Pilot, ${SCRIPT[i]}`;
        setResult(undefined);
        setPhase('hearing');
        for (let n = 1; n <= line.length && !stop; n++) {
          setText(line.slice(0, n));
          await sleep(reduce ? 0 : 32);
        }
        if (stop) return;
        setResult(plan(line));
        setPhase('acting');
        await sleep(3400);
      }
    })();
    return () => {
      stop = true;
    };
  }, [yours, reduce]);

  // a long command scrolls like a real field, so the newest words stay in view
  useEffect(() => {
    if (!yours && input.current) input.current.scrollLeft = input.current.scrollWidth;
  }, [text, yours]);

  const steps = result?.plan.kind === 'run' ? result.plan.steps : [];
  useEffect(() => {
    if (phase !== 'acting') return;
    const t = setTimeout(() => setPhase('ready'), (steps.length * STEP_S + 0.5) * 1000);
    return () => clearTimeout(t);
  }, [phase, steps.length]);

  const view = result && hud(result.plan, result.ms);

  return (
    <div className="relative overflow-hidden rounded-xl border border-line bg-surface-1 p-5 shadow-window sm:p-7">
      <div className="flex items-center gap-3">
        <img src="/favicon.svg" alt="" width={36} height={36} className="size-9" />
        <div className="leading-tight">
          <p className="text-small font-medium">Pilot</p>
          <p className={`font-mono text-micro ${phase === 'ready' ? 'text-fg-3' : 'text-signal'}`}>
            {STATUS[phase]}
          </p>
        </div>
      </div>

      <label className="mt-6 flex h-14 items-center gap-3 rounded-lg border border-line-strong bg-surface-2 px-4 focus-within:border-fg-3">
        <Wave on={phase !== 'ready'} />
        <span className="sr-only">Command</span>
        <input
          ref={input}
          value={text}
          onChange={(e) => setText(e.target.value)}
          onFocus={() => {
            if (yours) return;
            setYours(true);
            setText('');
            setPhase('ready');
            setResult(undefined);
          }}
          onKeyDown={(e) => {
            if (e.key !== 'Enter' || !text.trim()) return;
            const r = plan(text);
            setResult(r);
            setPhase(r.plan.kind === 'run' ? 'acting' : 'ready');
          }}
          placeholder="Type a command, then press Enter"
          spellCheck={false}
          autoComplete="off"
          className="min-w-0 flex-1 bg-transparent font-mono text-small text-fg outline-none placeholder:text-fg-3"
        />
      </label>

      <div className="mt-4 min-h-32" aria-live={yours ? 'polite' : 'off'}>
        <AnimatePresence mode="wait">
          {view && (
            <motion.div
              key={`${text}${result?.ms}`}
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0 }}
              transition={{ duration: base, ease: easeOut }}
            >
              <p className="inline-flex max-w-full items-start gap-2 rounded-md bg-raised px-3.5 py-2.5 text-small shadow-hud">
                <span aria-hidden className={view.ok ? 'text-signal' : 'text-fg-3'}>
                  {view.ok ? '✓' : '·'}
                </span>
                <span className={view.ok ? 'text-fg' : 'text-fg-2'}>{view.text}</span>
              </p>
              {steps.length > 0 && (
                <motion.ol
                  initial="hidden"
                  animate="shown"
                  variants={{ shown: { transition: { staggerChildren: STEP_S } } }}
                  className="mt-4 space-y-1.5 font-mono text-micro text-fg-3"
                >
                  {steps.map((s, i) => (
                    <motion.li
                      key={i}
                      variants={{ hidden: { opacity: 0, x: -4 }, shown: { opacity: 1, x: 0 } }}
                      transition={{ duration: base, ease: easeOut }}
                      className="flex gap-3"
                    >
                      <span className="w-28 shrink-0 truncate text-fg-2">{s.id}</span>
                      <span className="truncate">{s.actions.map(actionLabel).join(' · ')}</span>
                    </motion.li>
                  ))}
                </motion.ol>
              )}
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}

/** Five bars that move while Pilot hears and acts on a command: the accent's main job. */
function Wave({ on }: { on: boolean }) {
  return (
    <span aria-hidden className="flex h-5 w-6 shrink-0 items-center justify-between">
      {[0.55, 0.9, 1, 0.75, 0.45].map((h, i) => (
        <span
          key={i}
          style={{ height: `${h * 100}%`, animationDelay: `${i * -170}ms` }}
          className={`w-[3px] origin-center rounded-full transition-colors ${on ? 'animate-wave bg-signal' : 'scale-y-[0.25] bg-fg-3'}`}
        />
      ))}
    </span>
  );
}
