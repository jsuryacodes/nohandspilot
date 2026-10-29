// Real files from this repo, shown in the mock VS Code: the commands the site runs on, the Swift it was ported
// from, and the README.
import brainSwift from '../../../app/Sources/PilotBrain/Brain.swift?raw';
import commandsJson from '../../../commands/commands.json?raw';
import readme from '../../../README.md?raw';
import { config } from '../brain/site';

export const FILES: Record<string, string> = {
  'commands.json': commandsJson,
  'Brain.swift': brainSwift,
  'README.md': readme,
};
export const README = readme;

/** "What can I say?", built like Pilot's own help window (main.swift helpText): every phrase, by app. */
export interface HelpGroup {
  title: string;
  rows: { phrases: string[]; note?: string }[];
}
const apps = [...new Set(config.commands.flatMap((c) => (c.app ? [c.app] : [])))].sort();
export const HELP: HelpGroup[] = [
  ...[undefined, ...apps].map((app) => ({
    title: app ?? 'Anywhere',
    rows: config.commands
      .filter((c) => c.app === app)
      .map((c) => ({
        phrases: c.phrases,
        note: (c.action.keys ?? '').toUpperCase().startsWith('TODO') ? 'not set up yet' : undefined,
      })),
  })),
  {
    title: 'Macros',
    rows: Object.entries(config.macros).map(([name, lines]) => ({
      phrases: [name],
      note: lines.join(', '),
    })),
  },
  {
    title: 'Websites ("open github", "search youtube for lofi")',
    rows: [{ phrases: Object.keys(config.sites ?? {}).sort() }],
  },
];
export const HELP_ROWS = HELP.reduce((n, g) => n + g.rows.length + 1, 0);
