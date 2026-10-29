import { useEffect, useState, type ReactNode } from 'react';
import type { App } from '../brain/site';
import { ThemeSwitch } from '../ThemeSwitch';
import { Airplane, BatteryGlyph, WifiGlyph } from './icons';

function useNow() {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    const t = setInterval(() => setNow(new Date()), 15_000);
    return () => clearInterval(t);
  }, []);
  return now;
}

/** A menu-bar item with a dropdown that closes on Escape or a click outside. */
function Menu({
  label,
  button,
  right = false,
  children,
}: {
  label: string;
  button: ReactNode;
  right?: boolean;
  children: ReactNode;
}) {
  const [open, setOpen] = useState(false);
  return (
    <div className="relative" onKeyDown={(e) => e.key === 'Escape' && setOpen(false)}>
      <button
        type="button"
        aria-label={label}
        aria-expanded={open}
        onClick={() => setOpen(!open)}
        className={`flex h-[22px] items-center rounded-[5px] px-2 ${open ? 'bg-os-select' : 'hover:bg-os-hover'}`}
      >
        {button}
      </button>
      {open && (
        <>
          <div className="fixed inset-0 z-10" onPointerDown={() => setOpen(false)} />
          <div
            className={`absolute top-[26px] z-20 w-[260px] space-y-2 rounded-md border border-os-line bg-os-menu p-3 shadow-hud backdrop-blur-2xl ${right ? 'right-0' : 'left-0'}`}
          >
            {children}
          </div>
        </>
      )}
    </div>
  );
}

/** The menu bar: the site's own menu where the Apple menu would be, the front app, Pilot's airplane, a clock. */
export function MenuBar({
  front,
  count,
  onHelp,
}: {
  front: App;
  count: number;
  onHelp: () => void;
}) {
  const now = useNow();
  const date = now.toLocaleDateString('en-GB', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
  });
  const time = now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
  return (
    <div className="absolute inset-x-0 top-0 z-[1000] flex h-6 items-center bg-os-bar px-1.5 font-os text-[13px] text-os-text backdrop-blur-2xl">
      <Menu
        label="About this desktop"
        button={<img src="/favicon.svg" alt="" className="size-4" />}
      >
        <p className="font-semibold">A Mac in your browser</p>
        <p className="text-[12px] leading-snug text-os-text-2">
          Commands go through Pilot’s Brain, ported to TypeScript and passing all of its Swift
          tests, and the real commands.json. The apps are stand-ins: nothing here touches your
          computer.
        </p>
        <div className="flex items-center justify-between border-t border-os-line pt-2">
          <span className="text-[12px] text-os-text-2">Appearance</span>
          <ThemeSwitch />
        </div>
        <a href="/" className="block rounded-[5px] px-2 py-1 font-medium hover:bg-os-hover">
          ← Back to the website
        </a>
      </Menu>
      <span className="px-2 font-bold">{front}</span>
      {['File', 'Edit', 'View', 'Window', 'Help'].map((m) => (
        <span key={m} aria-hidden className="hidden px-2 md:block">
          {m}
        </span>
      ))}
      <span className="flex-1" />
      <Menu label="Pilot" right button={<Airplane className="size-4" />}>
        <p className="font-semibold">Pilot</p>
        <p className="text-os-text-2">
          Today: {count} command{count === 1 ? '' : 's'}, on this page
        </p>
        <button
          type="button"
          onClick={onHelp}
          className="block w-full rounded-[5px] px-2 py-1 text-left font-medium hover:bg-os-hover"
        >
          What can I say?
        </button>
      </Menu>
      <WifiGlyph className="mx-2 hidden size-4 sm:block" />
      <BatteryGlyph className="mx-1.5 hidden h-3 w-6 sm:block" />
      <span className="px-2 tabular-nums">
        {date.replace(',', '')} {time}
      </span>
    </div>
  );
}
