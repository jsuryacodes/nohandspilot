import { motion, useDragControls, useMotionValue, useReducedMotion } from 'framer-motion';
import { useEffect, useRef, type ReactNode, type RefObject } from 'react';
import { easeOut, slow } from '../motion';

export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

interface Props {
  label: string;
  title: ReactNode;
  active: boolean; // the front window: coloured traffic lights
  z: number;
  rect: Rect;
  full?: Rect; // set while full screen
  minimised: boolean;
  hidden: boolean;
  stage: RefObject<HTMLDivElement | null>;
  stageHeight: number;
  onFocus: () => void;
  onClose: () => void;
  onMinimise: () => void;
  onFull: () => void;
  children: ReactNode;
}

/** A Mac window: dragged by its title bar, brought forward by a click, and animated as it opens, closes,
 *  minimises (down towards the Dock) and goes full screen. */
export function Window(p: Props) {
  const controls = useDragControls();
  const x = useMotionValue(0);
  const y = useMotionValue(0);
  const r = p.full ?? p.rect;
  const away = p.minimised || p.hidden;

  return (
    <motion.section
      aria-label={`${p.label} window`}
      inert={away}
      className="absolute flex flex-col overflow-hidden rounded-md bg-os-window font-os text-[13px] text-os-text shadow-window"
      // full screen ignores where it was dragged; leaving it puts the window back there, as on a Mac
      style={{ x: p.full ? 0 : x, y: p.full ? 0 : y, zIndex: p.z, transformOrigin: '50% 100%' }}
      initial={{ opacity: 0, scale: 0.94, left: r.x, top: r.y, width: r.w, height: r.h }}
      animate={{
        opacity: away ? 0 : 1,
        scale: p.minimised ? 0.18 : 1,
        left: r.x,
        top: p.minimised ? p.stageHeight - r.h * 0.4 : r.y,
        width: r.w,
        height: r.h,
        borderRadius: p.full ? 0 : 12,
      }}
      exit={{ opacity: 0, scale: 0.96 }}
      transition={{ duration: slow, ease: easeOut }}
      drag={!p.full}
      dragControls={controls}
      dragListener={false}
      dragMomentum={false}
      dragElastic={0}
      dragConstraints={p.stage}
      onPointerDownCapture={p.onFocus}
    >
      <header
        onPointerDown={(e) => !p.full && controls.start(e)}
        className="relative flex h-[38px] shrink-0 cursor-default select-none items-center bg-os-chrome"
      >
        <Lights {...p} />
        <div className="flex min-w-0 flex-1 self-stretch">{p.title}</div>
      </header>
      <div className="relative min-h-0 flex-1 border-t border-os-line">{p.children}</div>
    </motion.section>
  );
}

function Lights({ label, active, onClose, onMinimise, onFull }: Props) {
  const lights = [
    {
      name: `Close ${label}`,
      on: onClose,
      color: 'bg-os-close group-hover/lights:bg-os-close',
      glyph: 'M4 4l4 4m0-4-4 4',
    },
    {
      name: `Minimise ${label}`,
      on: onMinimise,
      color: 'bg-os-min group-hover/lights:bg-os-min',
      glyph: 'M3.5 6h5',
    },
    {
      name: `Full screen ${label}`,
      on: onFull,
      color: 'bg-os-zoom group-hover/lights:bg-os-zoom',
      glyph: 'M4 3.5h4.5V8M8 8.5H3.5V4',
    },
  ];
  return (
    <div
      className="group/lights flex shrink-0 items-center gap-2 px-[13px]"
      onPointerDown={(e) => e.stopPropagation()}
    >
      {lights.map((l) => (
        <button
          key={l.name}
          type="button"
          aria-label={l.name}
          onClick={l.on}
          className={`grid size-3 place-items-center rounded-full ${active ? l.color : `bg-os-control ${l.color.split(' ')[1]}`}`}
        >
          <svg
            viewBox="0 0 12 12"
            aria-hidden
            className="size-2.5 stroke-black/55 opacity-0 group-hover/lights:opacity-100"
            strokeWidth="1.4"
            strokeLinecap="round"
            fill="none"
          >
            <path d={l.glyph} />
          </svg>
        </button>
      ))}
    </div>
  );
}

/** Keeps a scroll area where the simulation says it is (in screens), smoothly unless motion is reduced. */
export function useScrollTo(screens: number) {
  const ref = useRef<HTMLDivElement>(null);
  const reduce = useReducedMotion();
  useEffect(() => {
    const el = ref.current;
    if (el) el.scrollTo({ top: screens * el.clientHeight, behavior: reduce ? 'auto' : 'smooth' });
  }, [screens, reduce]);
  return ref;
}
