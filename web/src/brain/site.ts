// The Brain as the website runs it: the real commands.json, with the mock desktop's apps as the installed apps.
import commands from '@commands';
import { Brain, type Config, type Plan, type SlotValues } from './brain';

export const config = commands as Config;
export const APPS = [
  'Finder',
  'Google Chrome',
  'Visual Studio Code',
  'Claude',
  'Terminal',
  'Music',
  'System Settings',
  'NoHandsPilot',
] as const;
export type App = (typeof APPS)[number];

// What the Mac fills in at runtime (Hands.knownFolders, Hands.chromeProfiles), here for the mock Mac.
// Without them those slots would be free text, and "open blorp" would look like a folder.
// prettier-ignore
export const SLOTS: SlotValues = {
  folder: [['downloads', 'Downloads'], ['documents', 'Documents'], ['desktop', 'Desktop'], ['home', 'Home'], ['applications', 'Applications']],
  profile: [['Personal', 'Default'], ['Work', 'Profile 1'], ['College', 'Profile 2']],
};

export const makeBrain = (macros: Record<string, string[]> = {}) =>
  new Brain({ ...config, macros: { ...config.macros, ...macros } }, [...APPS], {}, SLOTS);
export const brain = makeBrain();
// Pilot's Brain is always running on the Mac; one throwaway plan gets this one past its cold start too.
brain.plan('open chrome, new tab, search for docker networking', undefined, {
  requireTrigger: false,
});

/** Plans a command the way Pilot's command bar does ("Pilot" optional) and times the match. */
export function plan(
  text: string,
  frontmostApp?: string,
  b: Brain = brain,
): { plan: Plan; ms: number } {
  const t0 = performance.now();
  const p = b.plan(text, frontmostApp, { requireTrigger: false });
  return { plan: p, ms: performance.now() - t0 };
}

// prettier-ignore
const GLYPHS: Record<string, string> = {
  cmd: '⌘', shift: '⇧', opt: '⌥', alt: '⌥', ctrl: '⌃', enter: '↩', esc: '⎋', tab: '⇥',
  space: 'Space', up: '↑', down: '↓', left: '←', right: '→',
};
/** "cmd+shift+t" → "⌘⇧T" */
export const keysLabel = (keys: string) =>
  keys
    .split('+')
    .map((k) => GLYPHS[k] ?? k.toUpperCase())
    .join('');

/** Time as the HUD shows it: "0.6 ms" */
export const msLabel = (ms: number) => `${ms < 0.1 ? '<0.1' : ms.toFixed(1)} ms`;

/** What Pilot's HUD says about a plan, in its own words: the commands' "say" lines, or why it didn't run. */
export function hud(p: Plan, ms: number): { ok: boolean; text: string } {
  const time = ` · ${msLabel(ms)}`;
  switch (p.kind) {
    case 'run':
      return { ok: true, text: p.steps.map((s) => s.say).join(' → ') + time };
    case 'unmatched':
      return {
        ok: false,
        text: `Didn't catch "${p.segment}"` + (p.suggestion ? `. Try "${p.suggestion}"` : ''),
      };
    case 'teach':
      return {
        ok: true,
        text: `On your Mac: learns "${p.phrase ?? 'that'}" → ${p.commands.join(', ')}` + time,
      };
    case 'forget':
      return { ok: true, text: `On your Mac: forgets "${p.phrase}"` + time };
    case 'notForPilot':
      return { ok: false, text: 'Not for Pilot' };
  }
}
