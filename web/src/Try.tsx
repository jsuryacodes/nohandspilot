import { PilotDesktop } from './desktop/PilotDesktop';
import { ThemeSwitch } from './ThemeSwitch';

/** /try: the Mac fills the screen on a laptop; on a phone it's scaled down, with the controls below it. */
export function Try() {
  return (
    <main className="min-[900px]:h-dvh">
      <h1 className="sr-only">Try No Hands Pilot</h1>
      <header className="flex items-center justify-between px-5 py-4 min-[900px]:hidden">
        <a href="/" className="flex items-center gap-2.5 rounded-sm">
          <img src="/favicon.svg" alt="" width={28} height={28} className="size-7" />
          <span className="whitespace-nowrap font-display text-[1.1875rem]">No Hands Pilot</span>
        </a>
        <ThemeSwitch />
      </header>
      <div className="px-4 pb-10 min-[900px]:h-full min-[900px]:p-0">
        <PilotDesktop autoplay={['open Chrome, new tab, search for Docker networking']} />
      </div>
    </main>
  );
}
