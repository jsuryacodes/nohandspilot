import { AnimatePresence, motion } from 'framer-motion';
import { msLabel } from '../brain/site';
import { base, easeOut } from '../motion';

export interface HudLine {
  text: string;
  kind: 'pending' | 'active' | 'done' | 'mac' | 'error';
  link?: string; // a real page the step opens: a link, because browsers block pop-ups that come late
}
export interface HudState {
  id: number;
  lines: HudLine[];
  ms: number; // the Brain's match time, measured
  miss?: string; // "Didn't catch …"
}

const MARK: Record<HudLine['kind'], { glyph: string; className: string }> = {
  pending: { glyph: '○', className: 'text-fg-3' },
  active: { glyph: '●', className: 'animate-pulse text-signal' },
  done: { glyph: '✓', className: 'text-signal' },
  mac: { glyph: '↗', className: 'text-fg-3' },
  error: { glyph: '⚠︎', className: 'text-fg-3' },
};

/** Pilot's toast: what it did, step by step for a chain, with the real match time. */
export function Hud({ hud, announce }: { hud?: HudState; announce: boolean }) {
  return (
    <div
      aria-live={announce ? 'polite' : 'off'}
      className="pointer-events-none flex justify-center px-3"
    >
      <AnimatePresence>
        {hud && (
          <motion.div
            key={hud.id}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 4 }}
            transition={{ duration: base, ease: easeOut }}
            className="pointer-events-auto max-w-[560px] rounded-md bg-raised px-4 py-2.5 text-small text-fg shadow-hud"
          >
            {hud.miss ? (
              <p className="text-fg-2">
                <span aria-hidden className="mr-2 text-fg-3">
                  ·
                </span>
                {hud.miss}
              </p>
            ) : (
              <ol className="space-y-1">
                {hud.lines.map((l, i) => (
                  <li
                    key={i}
                    className={`flex gap-2 ${l.kind === 'pending' ? 'text-fg-3' : l.kind === 'done' || l.kind === 'active' ? '' : 'text-fg-2'}`}
                  >
                    <span
                      aria-hidden
                      className={`w-3 shrink-0 text-center ${MARK[l.kind].className}`}
                    >
                      {MARK[l.kind].glyph}
                    </span>
                    <span>
                      {l.text}
                      {l.link && (
                        <a
                          href={l.link}
                          target="_blank"
                          rel="noreferrer"
                          className="ml-2 underline underline-offset-2"
                        >
                          Open ↗
                        </a>
                      )}
                      {i === hud.lines.length - 1 && (
                        <span className="text-fg-3"> · {msLabel(hud.ms)}</span>
                      )}
                    </span>
                  </li>
                ))}
              </ol>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
