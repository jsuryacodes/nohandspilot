import type { Stats } from '../stats';
import { BEFORE_AFTER, CHAIN, TAUGHT, TEACH, TEACH_THAT } from './said';
import { Card, Said, Section } from './ui';

export function Problem() {
  return (
    <Section
      id="why"
      eyebrow="Why I built it"
      title="I could type by voice. My hand still went to the trackpad."
    >
      <div className="mt-10 grid gap-12 lg:grid-cols-[minmax(0,0.8fr)_minmax(0,1.2fr)] lg:gap-16">
        <div className="max-w-[46ch] space-y-5 text-body text-fg-2">
          <p>
            Wispr Flow turns what I say into text anywhere on my Mac. But between the sentences I
            was still opening apps, switching tabs, clicking buttons and scrolling, all by hand.
          </p>
          <p>
            Pilot is the other half. You say the command the way you already dictate, and the Mac
            does it.
          </p>
          <p className="text-fg">
            It’s for anyone who already dictates with Wispr and wants the last bit of hands-free.
          </p>
        </div>
        <Card className="overflow-hidden">
          <table className="w-full text-left text-small">
            <caption className="sr-only">
              Things I used to do by hand, and what I say to Pilot instead
            </caption>
            <thead>
              <tr className="border-b border-line font-mono text-micro uppercase tracking-[0.12em] text-fg-3">
                <th scope="col" className="hidden px-5 py-3 font-normal sm:table-cell">
                  To
                </th>
                <th scope="col" className="px-5 py-3 font-normal">
                  By hand
                </th>
                <th scope="col" className="px-5 py-3 font-normal">
                  With Pilot
                </th>
              </tr>
            </thead>
            <tbody>
              {BEFORE_AFTER.map((r) => (
                <tr key={r.task} className="border-b border-line last:border-0">
                  <th scope="row" className="hidden px-5 py-3.5 font-normal text-fg sm:table-cell">
                    {r.task}
                  </th>
                  <td className="px-5 py-3.5 text-fg-3">{r.hand}</td>
                  <td className="px-5 py-3.5">
                    <Said>{r.said}</Said>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      </div>
    </Section>
  );
}

const FLOW = [
  {
    step: 'You say it',
    who: 'Wispr Flow',
    text: (
      <>
        Hold your Wispr key and talk as usual: <Said>{CHAIN}</Said>. Wispr Flow turns it into text.
      </>
    ),
  },
  {
    step: 'Pilot catches it',
    who: 'Before it’s pasted',
    text: (
      <>
        Wispr pastes with ⌘V. When the text starts with “Pilot”, Pilot takes the paste before it
        reaches the text box.
      </>
    ),
  },
  {
    step: 'The Brain matches it',
    who: 'commands.json',
    text: (
      <>
        Phrases with slots, synonyms, app names, commands for one app, and chains split on commas.
        Rule-based, on your Mac.
      </>
    ),
  },
  {
    step: 'Its hands act',
    who: 'macOS Accessibility',
    text: (
      <>
        Key presses and Accessibility do the rest: Chrome comes forward, ⌘T opens a tab, the search
        goes in.
      </>
    ),
  },
];

export function HowItWorks({ stats }: { stats?: Stats }) {
  const facts = [
    {
      big: stats ? `${stats.matchMs.median} ms` : '…',
      text:
        'The median time to match a command, from my usage log.' +
        (stats?.sample ? ' (Sample data.)' : ''),
    },
    { big: 'Offline', text: 'Matching runs on your Mac. No AI round-trip, no API keys.' },
    {
      big: 'Untouched',
      text: 'Dictation that doesn’t start with “Pilot” types exactly as it always did.',
    },
  ];
  return (
    <Section id="how" eyebrow="How it works" title="Wispr writes it down. Pilot does it.">
      <ol className="mt-12 grid gap-px overflow-hidden rounded-xl border border-line bg-line md:grid-cols-2 lg:grid-cols-4">
        {FLOW.map((f, i) => (
          <li key={f.step} className="relative bg-surface-1 p-6">
            <p className="font-mono text-micro text-fg-3">
              {String(i + 1).padStart(2, '0')} · {f.who}
            </p>
            <h3 className="mt-3 text-lead font-semibold">{f.step}</h3>
            <p className="mt-2 text-small text-fg-2">{f.text}</p>
          </li>
        ))}
      </ol>
      <div className="mt-12 grid gap-8 sm:grid-cols-3">
        {facts.map((f) => (
          <div key={f.big} className="border-t border-line pt-5">
            <p className="text-[2rem] font-semibold leading-none tracking-tight">{f.big}</p>
            <p className="mt-3 max-w-[30ch] text-small text-fg-2">{f.text}</p>
          </div>
        ))}
      </div>
      <div className="mt-12 grid gap-4 lg:grid-cols-2">
        <Card className="p-7">
          <h3 className="text-lead font-semibold">No hands at all</h3>
          <p className="mt-3 text-small text-fg-2">
            With the wake word on, Pilot listens on-device for its name only, then starts Wispr
            Flow. Wispr transcribes every command. Say “Pilot”, wait for 🎙 Listening…, then say the
            command.
          </p>
          <p className="mt-3 text-small text-fg-2">
            The only word Pilot acts on from its own speech recognizer is “Pilot”. Every word after
            it comes from Wispr Flow. Nothing Apple’s recognizer transcribes besides the name is
            ever run, typed, joined into a command or logged.
          </p>
        </Card>
        <Card className="p-7">
          <h3 className="text-lead font-semibold">Teach it by voice</h3>
          <p className="mt-3 text-small text-fg-2">
            <Said>{TEACH}</Said>
          </p>
          <p className="mt-2 text-small text-fg-2">
            From then on, <Said>{TAUGHT}</Said> runs both. Missed a phrase? Right after the miss,
            say <Said>{TEACH_THAT}</Said>. Taught phrases are saved next to commands.json.
          </p>
        </Card>
      </div>
    </Section>
  );
}
