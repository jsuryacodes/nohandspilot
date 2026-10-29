import { useEffect, useState } from 'react';

/** web/public/stats.json, written by scripts/export-stats.mjs from Pilot's usage log. */
export interface Stats {
  sample?: true; // stats.example.json: made-up numbers, labelled on the page
  exportedAt: string;
  firstDay: string;
  lastDay: string;
  commands: number;
  ok: number;
  failed: number;
  chains: number;
  sources: Partial<Record<'wispr' | 'voice' | 'bar', number>>;
  days: { date: string; commands: number; ok: number }[];
  top: { id: string; count: number }[];
  matchMs: { median: number; p95: number };
  totalMs: { median: number; p95: number };
}

async function load(path: string): Promise<Stats | undefined> {
  try {
    const r = await fetch(path);
    return r.ok ? ((await r.json()) as Stats) : undefined;
  } catch {
    return undefined; // missing, or the host sent the page instead of JSON
  }
}

const stats = load('/stats.json').then((s) => s ?? load('/stats.example.json'));

export function useStats() {
  const [value, setValue] = useState<Stats>();
  useEffect(() => {
    stats.then(setValue);
  }, []);
  return value;
}

/** "2026-10-28" → "28 Oct" */
export const day = (iso: string) =>
  new Date(`${iso.slice(0, 10)}T12:00:00`).toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'short',
  });
