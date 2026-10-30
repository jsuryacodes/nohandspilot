import { useLayoutEffect, useRef, useState } from 'react';
import { config } from '../brain/site';
import { day, type Stats } from '../stats';
import { Card, Section } from './ui';

const fmt = (n: number) => n.toLocaleString('en-GB');
const pct = (part: number, whole: number) => (whole ? Math.round((part / whole) * 100) : 0);

/** A command id as you'd say it: its first phrase in commands.json ("open_app" → "open {app}"), and the app it's for. */
function phrase(id: string) {
  const c = config.commands.find((x) => x.id === id);
  if (!c)
    return (
      (
        { menu: 'a menu item', teach: 'teach that …', forget: 'forget …' } as Record<string, string>
      )[id] ?? id
    );
  return c.app ? `${c.phrases[0]}  (in ${c.app})` : c.phrases[0];
}
const share = (part: number, whole: number) =>
  part && pct(part, whole) === 0 ? '<1' : pct(part, whole);

const SOURCES: { key: 'wispr' | 'voice' | 'bar'; label: string; note: string }[] = [
  {
    key: 'wispr',
    label: 'Wispr Flow typed it',
    note: 'Wispr’s key, or after the wake word',
  },
  {
    key: 'voice',
    label: 'Pilot’s own hearing',
    note: 'commands started by the wake word, in Apple’s words (before 30 Oct)',
  },
  { key: 'bar', label: 'Command bar', note: '⌃⌥P, typed or dictated' },
];

export function Usage({ stats }: { stats?: Stats }) {
  return (
    <Section
      id="usage"
      eyebrow="My real usage"
      title={
        <>
          Every command I’ve said to Pilot.
          {stats?.sample && <SampleTag />}
        </>
      }
    >
      {stats ? <Numbers s={stats} /> : <div className="mt-10 h-[540px]" />}
    </Section>
  );
}

const SampleTag = () => (
  <span className="ml-3 inline-block -translate-y-2 rounded-xs border border-fg-3 px-2 py-0.5 align-middle font-mono text-micro uppercase tracking-[0.1em] text-fg-2">
    Sample data
  </span>
);

function Numbers({ s }: { s: Stats }) {
  const tiles = [
    { label: 'Commands', value: fmt(s.commands), note: 'said to Pilot' },
    {
      label: 'Ran',
      value: fmt(s.ok),
      note: `${pct(s.ok, s.commands)}% of them; the rest it didn’t catch or couldn’t do`,
    },
    { label: 'Chains', value: fmt(s.chains), note: 'two or more steps in one go' },
    {
      label: 'Median match',
      value: `${s.matchMs.median} ms`,
      note: `95% within ${s.matchMs.p95} ms`,
    },
    { label: 'Median run', value: `${s.totalMs.median} ms`, note: 'matched, then done on the Mac' },
  ];
  return (
    <>
      <p className="mt-5 max-w-[60ch] text-body text-fg-2">
        From Pilot’s usage log on my Mac, {day(s.firstDay)}–{day(s.lastDay)}, exported from my Mac
        on {day(s.exportedAt)}. Counts and timings only: what I said stays on my Mac.
      </p>
      <dl className="mt-10 grid grid-cols-2 gap-x-6 gap-y-8 sm:grid-cols-3 lg:grid-cols-5">
        {tiles.map((t) => (
          <div key={t.label} className="border-t border-line pt-4">
            <dt className="text-small text-fg-2">{t.label}</dt>
            <dd className="mt-1 text-[2.25rem] font-semibold leading-tight tracking-tight">
              {t.value}
            </dd>
            <dd className="mt-1 text-micro text-fg-3">{t.note}</dd>
          </div>
        ))}
      </dl>
      <div className="mt-10 grid gap-4 lg:grid-cols-[minmax(0,1.1fr)_minmax(0,0.9fr)]">
        <Card className="p-6">
          <h3 className="text-small font-semibold">Commands per day</h3>
          <PerDay days={s.days} />
        </Card>
        <Card className="p-6">
          <h3 className="text-small font-semibold">How they reached Pilot</h3>
          <Bars
            rows={SOURCES.map((src) => ({
              label: src.label,
              note: src.note,
              value: s.sources[src.key] ?? 0,
            }))}
            total={s.commands}
          />
        </Card>
        <Card className="p-6 lg:col-span-2">
          <h3 className="text-small font-semibold">Most used, by what you say</h3>
          <Bars rows={s.top.map((t) => ({ label: phrase(t.id), mono: true, value: t.count }))} />
        </Card>
      </div>
    </>
  );
}

/** Horizontal bars, one series: the label, the bar, the value at its tip. */
function Bars({
  rows,
  total,
}: {
  rows: { label: string; note?: string; mono?: boolean; value: number }[];
  total?: number;
}) {
  const max = Math.max(1, ...rows.map((r) => r.value));
  return (
    <ul className="mt-5 space-y-3.5">
      {rows.map((r) => (
        <li
          key={r.label}
          className="grid items-center gap-x-4 gap-y-1.5 text-small sm:grid-cols-[minmax(0,15rem)_minmax(0,1fr)]"
        >
          <span className="min-w-0">
            <span className={`block ${r.mono ? 'font-mono text-[0.85rem]' : ''}`}>{r.label}</span>
            {r.note && <span className="block text-micro text-fg-3">{r.note}</span>}
          </span>
          <span className="flex items-center gap-2.5">
            <span
              className="h-2 rounded-r-[4px] bg-fg/80"
              style={{ width: `${(r.value / max) * 82}%`, minWidth: r.value ? 2 : 0 }}
            />
            <span className="shrink-0 tabular-nums text-fg-2">
              {fmt(r.value)}
              {total ? <span className="text-fg-3"> · {share(r.value, total)}%</span> : null}
            </span>
          </span>
        </li>
      ))}
    </ul>
  );
}

/** Commands per day since the first: columns from one baseline, the latest and busiest days labelled, every day on
 *  hover or focus, and the whole series as a table for screen readers. */
/** The width a chart is drawn at, so its text stays at its real size on a phone too. */
function useWidth() {
  const ref = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(560);
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const ro = new ResizeObserver(([e]) => setWidth(Math.max(240, e.contentRect.width)));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  return [ref, width] as const;
}

function PerDay({ days }: { days: Stats['days'] }) {
  const [active, setActive] = useState<number>();
  const [box, W] = useWidth();
  const H = 210;
  const top = 26;
  const base = H - 30;
  const max = Math.max(1, ...days.map((d) => d.commands));
  const step = Math.pow(10, Math.floor(Math.log10(max)));
  const ceil = Math.ceil(max / step) * step; // a clean top for the scale
  const slot = W / days.length;
  const bar = Math.min(24, slot * 0.5);
  const y = (v: number) => base - ((base - top) * v) / ceil;
  const busiest = days.reduce((b, d, i) => (d.commands > days[b].commands ? i : b), 0);
  const labelled = new Set([busiest, days.length - 1]);
  const shown = active ?? -1;
  return (
    <div ref={box} className="relative mt-4">
      <svg viewBox={`0 0 ${W} ${H}`} className="w-full overflow-visible" aria-hidden>
        {[0, ceil / 2, ceil].map((t) => (
          <g key={t}>
            <line
              x1="0"
              x2={W}
              y1={y(t)}
              y2={y(t)}
              className="stroke-line"
              strokeWidth="1"
              vectorEffect="non-scaling-stroke"
            />
            <text x="0" y={y(t) - 6} className="fill-fg-3 font-mono text-[11px] tabular-nums">
              {fmt(t)}
            </text>
          </g>
        ))}
        {days.map((d, i) => {
          const x = slot * i + (slot - bar) / 2;
          const h = base - y(d.commands);
          const r = Math.min(4, h);
          return (
            <g key={d.date}>
              {h > 0 && (
                <path
                  d={`M${x} ${base}V${base - h + r}Q${x} ${base - h} ${x + r} ${base - h}H${x + bar - r}Q${x + bar} ${base - h} ${x + bar} ${base - h + r}V${base}Z`}
                  className={`fill-fg transition-opacity ${shown === -1 || shown === i ? 'opacity-85' : 'opacity-40'}`}
                />
              )}
              {labelled.has(i) && (
                <text
                  x={x + bar / 2}
                  y={base - h - 8}
                  textAnchor="middle"
                  className="fill-fg-2 text-[12px] tabular-nums"
                >
                  {fmt(d.commands)}
                </text>
              )}
              <text x={x + bar / 2} y={H - 8} textAnchor="middle" className="fill-fg-3 text-[11px]">
                {day(d.date)}
              </text>
            </g>
          );
        })}
      </svg>
      {/* hit areas: each whole day's slot, bigger than the column; keyboard focus shows the same as hover */}
      <div className="absolute inset-x-0 top-0 flex" style={{ height: `${(base / H) * 100}%` }}>
        {days.map((d, i) => (
          <button
            key={d.date}
            type="button"
            aria-label={`${day(d.date)}: ${d.commands} commands, ${d.ok} ran`}
            onPointerEnter={() => setActive(i)}
            onPointerLeave={() => setActive(undefined)}
            onFocus={() => setActive(i)}
            onBlur={() => setActive(undefined)}
            className="relative h-full flex-1 rounded-sm"
          >
            {active === i && (
              <span className="pointer-events-none absolute bottom-full left-1/2 z-10 mb-1 w-max -translate-x-1/2 rounded-sm bg-raised px-3 py-2 text-left text-micro shadow-hud">
                <strong className="block text-small font-semibold text-fg">
                  {fmt(d.commands)} commands
                </strong>
                <span className="text-fg-2">
                  {fmt(d.ok)} ran · {day(d.date)}
                </span>
              </span>
            )}
          </button>
        ))}
      </div>
      <table className="sr-only">
        <caption>Commands per day</caption>
        <thead>
          <tr>
            <th scope="col">Day</th>
            <th scope="col">Commands</th>
            <th scope="col">Ran</th>
          </tr>
        </thead>
        <tbody>
          {days.map((d) => (
            <tr key={d.date}>
              <th scope="row">{day(d.date)}</th>
              <td>{d.commands}</td>
              <td>{d.ok}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
