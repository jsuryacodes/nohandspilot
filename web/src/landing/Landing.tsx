import { GITHUB_URL, LICENSE_URL, PROFILE_URL, RELEASES_URL } from '../config';
import { PilotDesktop } from '../desktop/PilotDesktop';
import { day, useStats, type Stats } from '../stats';
import { ThemeSwitch } from '../ThemeSwitch';
import { BuiltByVoice, Demo } from './Media';
import { HERO_SHOW } from './said';
import { HowItWorks, Problem } from './Story';
import { Card } from './ui';
import { Usage } from './Usage';

const primary =
  'inline-flex h-12 items-center gap-2 rounded-md bg-fg px-5 font-medium text-canvas transition hover:bg-fg/90';
const secondary =
  'inline-flex h-12 items-center rounded-md border border-line-strong px-5 font-medium transition hover:bg-surface-2';

export function Landing() {
  const stats = useStats();
  return (
    <>
      <div aria-hidden className="grain pointer-events-none fixed inset-0 z-50 opacity-(--grain)" />
      <div
        aria-hidden
        className="pointer-events-none absolute inset-x-0 top-0 h-[720px] bg-[radial-gradient(60%_60%_at_50%_0%,var(--color-glow),transparent)]"
      />
      <header className="relative mx-auto flex max-w-[1200px] items-center justify-between px-5 py-5 md:px-8">
        <a href="/" className="flex shrink-0 items-center gap-2.5 rounded-sm">
          <img src="/favicon.svg" alt="" width={28} height={28} className="size-7" />
          <span className="whitespace-nowrap font-display text-[1.1875rem] tracking-[-0.01em]">
            No Hands Pilot
          </span>
        </a>
        <nav aria-label="Site" className="flex items-center gap-1 text-small">
          <a
            href="#how"
            className="hidden rounded-sm px-3 py-2 text-fg-2 transition hover:text-fg md:block"
          >
            How it works
          </a>
          <a
            href="#usage"
            className="hidden rounded-sm px-3 py-2 text-fg-2 transition hover:text-fg md:block"
          >
            Usage
          </a>
          <a
            href={GITHUB_URL}
            className="hidden rounded-sm px-3 py-2 text-fg-2 transition hover:text-fg sm:block"
          >
            GitHub
          </a>
          <ThemeSwitch className="ml-1" />
        </nav>
      </header>

      <main className="relative">
        <section className="mx-auto grid max-w-[1200px] items-center gap-12 px-5 pb-20 pt-8 md:px-8 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.15fr)] lg:gap-14 lg:pt-14">
          <div>
            <p className="font-mono text-micro uppercase tracking-[0.14em] text-fg-3">
              A Mac menu-bar app for Wispr Flow
            </p>
            <h1 className="mt-6 font-display text-display font-[380] text-balance">
              Use your Mac without touching it.
            </h1>
            <p className="mt-7 max-w-[30ch] text-lead text-fg-2">
              Wispr Flow is the ears. Pilot is the hands. No AI round-trip, no API keys, fully
              offline.
            </p>
            <div className="mt-9 flex flex-wrap gap-3">
              <a href="/try" className={primary}>
                Try it <span aria-hidden>→</span>
              </a>
              <a href={RELEASES_URL} className={secondary}>
                Get it for Mac
              </a>
            </div>
            <Proof stats={stats} />
          </div>
          <div>
            <h2 className="sr-only">Pilot running on a Mac, in your browser</h2>
            <PilotDesktop compact autoplay={HERO_SHOW} loop />
          </div>
        </section>

        <Problem />
        <HowItWorks stats={stats} />
        <Demo />
        <Usage stats={stats} />
        <BuiltByVoice />
        <GetIt />
      </main>
      <Footer />
    </>
  );
}

/** One line of real numbers from my Mac, or a clear label when the site only has the sample file. */
function Proof({ stats }: { stats?: Stats }) {
  return (
    <p className="mt-10 flex min-h-5 flex-wrap items-center gap-x-6 gap-y-2 font-mono text-micro text-fg-3">
      {stats && (
        <>
          <span>
            <span className="text-fg">{stats.ok}</span> commands run on my Mac,{' '}
            {day(stats.firstDay)}–{day(stats.lastDay)}
          </span>
          <span>
            median match <span className="text-fg">{stats.matchMs.median} ms</span>
          </span>
          {stats.sample && (
            <span className="rounded-xs border border-fg-3 px-1.5 py-0.5 uppercase tracking-[0.1em] text-fg-2">
              Sample data
            </span>
          )}
        </>
      )}
    </p>
  );
}

function GetIt() {
  const steps = [
    <>
      Download it, move Pilot to Applications and open it. It isn’t notarized, so the first time:
      System Settings → Privacy &amp; Security →{' '}
      <b className="font-semibold text-fg">Open Anyway</b>.
    </>,
    <>
      Turn Pilot on under Privacy &amp; Security →{' '}
      <b className="font-semibold text-fg">Accessibility</b>.
    </>,
    <>
      Add “Pilot” to Wispr Flow’s dictionary. Then hold your Wispr key and say{' '}
      <span className="font-mono text-[0.9em] text-fg">"Pilot, open Finder"</span>.
    </>,
  ];
  return (
    <section aria-labelledby="get-title" className="mx-auto max-w-[1200px] px-5 pb-24 md:px-8">
      <Card className="grid gap-10 p-8 md:p-12 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)] lg:gap-16">
        <div>
          <h2 id="get-title" className="font-display text-title font-[380] text-balance">
            Try it here, then on your Mac.
          </h2>
          <div className="mt-8 flex flex-wrap gap-3">
            <a href="/try" className={primary}>
              Try it in the browser <span aria-hidden>→</span>
            </a>
            <a href={RELEASES_URL} className={secondary}>
              Get it for Mac
            </a>
          </div>
          <p className="mt-6 text-small text-fg-3">
            macOS 13 or later · works with Wispr Flow · MIT licensed ·{' '}
            <a href={GITHUB_URL} className="text-fg-2 underline underline-offset-4 hover:text-fg">
              source on GitHub
            </a>
          </p>
        </div>
        <ol className="space-y-5">
          {steps.map((s, i) => (
            <li key={i} className="grid grid-cols-[2rem_1fr] gap-3 text-small text-fg-2">
              <span className="font-mono text-micro leading-[1.6rem] text-fg-3">
                {String(i + 1).padStart(2, '0')}
              </span>
              <span>{s}</span>
            </li>
          ))}
        </ol>
      </Card>
    </section>
  );
}

function Footer() {
  return (
    <footer className="border-t border-line">
      <div className="mx-auto flex max-w-[1200px] flex-col gap-6 px-5 py-10 text-small text-fg-3 md:flex-row md:items-center md:justify-between md:px-8">
        <div className="flex items-center gap-3">
          <img src="/favicon.svg" alt="" width={24} height={24} className="size-6" />
          <p>Built for No Hands: The Wispr Challenge. Not affiliated with Wispr.</p>
        </div>
        <nav aria-label="Footer" className="flex flex-wrap gap-x-6 gap-y-2">
          <a href={GITHUB_URL} className="hover:text-fg">
            GitHub
          </a>
          <a href={LICENSE_URL} className="hover:text-fg">
            MIT license
          </a>
          <a href={PROFILE_URL} className="hover:text-fg">
            @jsuryacodes
          </a>
        </nav>
      </div>
    </footer>
  );
}
