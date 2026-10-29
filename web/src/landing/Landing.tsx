import { GITHUB_URL, RELEASES_URL } from '../config';
import { day, useStats } from '../stats';
import { CommandDemo } from './CommandDemo';

export function Landing() {
  return (
    <>
      <div aria-hidden className="grain pointer-events-none fixed inset-0 z-50 opacity-[0.045]" />
      <div
        aria-hidden
        className="pointer-events-none absolute inset-x-0 top-0 h-[720px] bg-[radial-gradient(60%_60%_at_50%_0%,rgb(242_237_228/0.07),transparent)]"
      />
      <header className="relative mx-auto flex max-w-[1200px] items-center justify-between px-5 py-5 md:px-8">
        <a href="/" className="flex items-center gap-2.5 rounded-sm">
          <img src="/favicon.svg" alt="" width={28} height={28} className="size-7" />
          <span className="font-display text-[1.1875rem] tracking-[-0.01em]">No Hands Pilot</span>
        </a>
        <nav className="flex items-center gap-2 text-small">
          <a
            href={GITHUB_URL}
            className="rounded-sm px-3 py-2 text-paper-2 transition hover:text-paper"
          >
            GitHub
          </a>
          <a
            href="/try"
            className="rounded-md border border-line-strong px-3.5 py-2 transition hover:bg-ink-2"
          >
            Try it
          </a>
        </nav>
      </header>

      <main className="relative">
        <section className="mx-auto grid max-w-[1200px] items-center gap-14 px-5 pb-24 pt-10 md:px-8 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.05fr)] lg:gap-16 lg:pt-20">
          <div>
            <p className="font-mono text-micro uppercase tracking-[0.14em] text-paper-3">
              A Mac menu-bar app for Wispr Flow
            </p>
            <h1 className="mt-6 font-display text-display font-[380] text-balance">
              Use your Mac without touching it.
            </h1>
            <p className="mt-7 max-w-[30ch] text-lead text-paper-2">
              Wispr Flow is the ears. Pilot is the hands. No AI round-trip, no API keys, fully
              offline.
            </p>
            <div className="mt-9 flex flex-wrap gap-3">
              <a
                href="/try"
                className="inline-flex h-12 items-center gap-2 rounded-md bg-paper px-5 font-medium text-ink transition hover:bg-paper/90"
              >
                Try it <span aria-hidden>→</span>
              </a>
              <a
                href={RELEASES_URL}
                className="inline-flex h-12 items-center rounded-md border border-line-strong px-5 font-medium transition hover:bg-ink-2"
              >
                Get it for Mac
              </a>
            </div>
            <Proof />
          </div>
          <CommandDemo />
        </section>
      </main>
    </>
  );
}

/** One line of real numbers from my Mac, or a clear label when the site only has the sample file. */
function Proof() {
  const stats = useStats();
  return (
    <p className="mt-10 flex min-h-5 flex-wrap items-center gap-x-6 gap-y-2 font-mono text-micro text-paper-3">
      {stats && (
        <>
          <span>
            <span className="text-paper">{stats.ok}</span> commands run on my Mac,{' '}
            {day(stats.firstDay)}–{day(stats.lastDay)}
          </span>
          <span>
            median match <span className="text-paper">{stats.matchMs.median} ms</span>
          </span>
          {stats.sample && (
            <span className="rounded-xs border border-paper-3 px-1.5 py-0.5 uppercase tracking-[0.1em] text-paper-2">
              Sample data
            </span>
          )}
        </>
      )}
    </p>
  );
}
