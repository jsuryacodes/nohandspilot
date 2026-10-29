import {
  motion,
  useAnimate,
  useMotionValue,
  useReducedMotion,
  useSpring,
  useTransform,
  type MotionValue,
} from 'framer-motion';
import { useEffect, useRef } from 'react';
import { APPS, type App } from '../brain/site';
import { AppIcon } from './icons';

/** The Dock: magnifies under the pointer, bounces an app as it launches, a dot under each running app. */
export function Dock({
  running,
  scale,
  hidden,
  onOpen,
}: {
  running: App[];
  scale: number;
  hidden: boolean;
  onOpen: (app: App) => void;
}) {
  const mouseX = useMotionValue(Infinity);
  return (
    <motion.nav
      aria-label="Dock"
      animate={{ y: hidden ? 120 : 0 }}
      className="absolute inset-x-0 bottom-1.5 z-[900] flex justify-center"
      onPointerMove={(e) => e.pointerType === 'mouse' && mouseX.set(e.clientX)}
      onPointerLeave={() => mouseX.set(Infinity)}
    >
      <ul className="flex items-end gap-1.5 rounded-[22px] border border-os-line bg-os-dock px-2 pb-1 pt-2 shadow-hud backdrop-blur-2xl">
        {APPS.map((app) => (
          <DockItem
            key={app}
            app={app}
            mouseX={mouseX}
            scale={scale}
            running={running.includes(app)}
            onOpen={onOpen}
          />
        ))}
      </ul>
    </motion.nav>
  );
}

function DockItem({
  app,
  mouseX,
  scale,
  running,
  onOpen,
}: {
  app: App;
  mouseX: MotionValue<number>;
  scale: number;
  running: boolean;
  onOpen: (app: App) => void;
}) {
  const ref = useRef<HTMLButtonElement>(null);
  const reduce = useReducedMotion();
  const distance = useTransform(mouseX, (x) => {
    const b = ref.current?.getBoundingClientRect();
    return b ? (x - b.left - b.width / 2) / scale : Infinity;
  });
  const size = useSpring(useTransform(distance, [-150, 0, 150], [48, reduce ? 48 : 68, 48]), {
    mass: 0.1,
    stiffness: 170,
    damping: 14,
  });
  const [scope, animate] = useAnimate();
  const was = useRef(running);
  useEffect(() => {
    if (running && !was.current && !reduce)
      animate(scope.current, { y: [0, -16, 0, -7, 0] }, { duration: 0.8 });
    was.current = running;
  }, [running, reduce, animate, scope]);
  return (
    <li className="group relative flex flex-col items-center">
      <span className="pointer-events-none absolute -top-8 whitespace-nowrap rounded-sm bg-os-menu px-2 py-0.5 font-os text-[12px] text-os-text opacity-0 shadow-hud transition group-hover:opacity-100">
        {app}
      </span>
      <motion.button
        ref={ref}
        type="button"
        aria-label={running ? `${app}, open` : app}
        onClick={() => onOpen(app)}
        style={{ width: size, height: size }}
        className="block"
      >
        <span ref={scope} className="block size-full">
          <AppIcon app={app} className="size-full" />
        </span>
      </motion.button>
      <span aria-hidden className={`mt-1 size-1 rounded-full ${running ? 'bg-os-text' : ''}`} />
    </li>
  );
}
