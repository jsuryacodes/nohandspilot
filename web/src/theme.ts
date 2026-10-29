import { useSyncExternalStore } from 'react';

/** System follows the Mac (or phone); Light and Dark stick until changed. index.html applies it before first paint. */
export type Theme = 'system' | 'light' | 'dark';

const KEY = 'theme';
const prefersLight = matchMedia('(prefers-color-scheme: light)');
const listeners = new Set<() => void>();
let choice = read();

function read(): Theme {
  try {
    const saved = localStorage.getItem(KEY);
    if (saved === 'light' || saved === 'dark') return saved;
  } catch {
    // storage blocked (private window): the system's choice it is
  }
  return 'system';
}

function apply() {
  const light = choice === 'light' || (choice === 'system' && prefersLight.matches);
  document.documentElement.dataset.theme = light ? 'light' : 'dark';
  document
    .querySelector('meta[name="theme-color"]')
    ?.setAttribute('content', light ? '#f4f0e8' : '#08090b');
}

prefersLight.addEventListener('change', apply); // only changes anything while the choice is "system"

export function setTheme(next: Theme) {
  choice = next;
  try {
    if (next === 'system') localStorage.removeItem(KEY);
    else localStorage.setItem(KEY, next);
  } catch {
    // not saved, still applied
  }
  apply();
  listeners.forEach((l) => l());
}

export const useTheme = () =>
  useSyncExternalStore(
    (l) => {
      listeners.add(l);
      return () => listeners.delete(l);
    },
    () => choice,
  );
