#!/usr/bin/env node
// Pilot's usage log → web/public/stats.json, the numbers on the website.
//   node scripts/export-stats.mjs [path/to/usage.jsonl]
// Aggregates only: what you said (`text`) and the error messages (which can quote it) never leave this script.
import { readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const input = process.argv[2] ?? join(homedir(), 'Library/Application Support/Pilot/usage.jsonl');
const output = new URL('../web/public/stats.json', import.meta.url);

const lines = readFileSync(input, 'utf8').split('\n').filter((l) => l.trim());
const log = [];
for (const line of lines) {
  try {
    const { time, source, matched, ok, matchMs, totalMs } = JSON.parse(line);
    log.push({ day: time.slice(0, 10), source, matched, ok, matchMs, totalMs }); // `time` is local, so is the day
  } catch {
    // a line cut off mid-write
  }
}
if (!log.length) throw new Error(`No commands in ${input}`);

const percentile = (values, p) => {
  const sorted = values.filter((v) => typeof v === 'number').sort((a, b) => a - b);
  return sorted[Math.max(0, Math.ceil(p * sorted.length) - 1)] ?? null; // nearest rank: a time that really happened
};
const count = (keys) => {
  const counts = {};
  for (const k of keys) counts[k] = (counts[k] ?? 0) + 1;
  return counts;
};

// every day from the first to the last, including days with no commands
const byDay = Object.groupBy(log, (e) => e.day);
const days = [];
const first = log.map((e) => e.day).sort()[0];
const last = log.map((e) => e.day).sort().at(-1);
for (let d = new Date(`${first}T00:00:00Z`); d.toISOString().slice(0, 10) <= last; d.setUTCDate(d.getUTCDate() + 1)) {
  const date = d.toISOString().slice(0, 10);
  days.push({ date, commands: byDay[date]?.length ?? 0, ok: byDay[date]?.filter((e) => e.ok).length ?? 0 });
}

const ran = log.filter((e) => e.matched.length); // unmatched ones did nothing, so their totalMs is only the match
const now = new Date();
const offset = -now.getTimezoneOffset();
const pad = (n) => String(Math.floor(Math.abs(n))).padStart(2, '0');
const stats = {
  exportedAt: `${new Date(now.getTime() + offset * 60000).toISOString().slice(0, 19)}${offset < 0 ? '-' : '+'}${pad(offset / 60)}:${pad(offset % 60)}`,
  firstDay: first,
  lastDay: last,
  commands: log.length,
  ok: log.filter((e) => e.ok).length,
  failed: log.filter((e) => !e.ok).length,
  chains: log.filter((e) => e.matched.length > 1).length, // two or more steps: a chain or a macro
  sources: count(log.map((e) => e.source)), // wispr: Wispr typed it (held key or wake word), voice: Pilot's own hearing ran it, bar: the command bar
  days,
  top: Object.entries(count(log.flatMap((e) => e.matched)))
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, 10)
    .map(([id, n]) => ({ id, count: n })),
  matchMs: { median: percentile(log.map((e) => e.matchMs), 0.5), p95: percentile(log.map((e) => e.matchMs), 0.95) },
  totalMs: { median: percentile(ran.map((e) => e.totalMs), 0.5), p95: percentile(ran.map((e) => e.totalMs), 0.95) },
};

writeFileSync(output, JSON.stringify(stats, null, 2) + '\n');
console.log(`${stats.commands} commands (${first} to ${last}) → ${output.pathname}`);
