import { useState } from 'react';
import { DEMO_VIDEO_ID } from '../config';
import { Card, Section } from './ui';

/** 16:9, with a poster drawn here: YouTube (its no-cookie player) only loads once you press play. */
export function Demo() {
  const [playing, setPlaying] = useState(false);
  return (
    <Section id="demo" eyebrow="Demo" title="See it on a real Mac.">
      <div className="relative mt-10 aspect-video overflow-hidden rounded-xl border border-line bg-surface-1 shadow-window">
        {playing ? (
          <iframe
            src={`https://www.youtube-nocookie.com/embed/${DEMO_VIDEO_ID}?autoplay=1&rel=0`}
            title="No Hands Pilot demo"
            allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
            className="absolute inset-0 size-full"
          />
        ) : (
          <div className="absolute inset-0 grid place-items-center bg-[radial-gradient(70%_80%_at_30%_10%,var(--color-glow),transparent)] p-6 text-center">
            <div>
              <img
                src="/favicon.svg"
                alt=""
                width={72}
                height={72}
                className="mx-auto size-14 sm:size-18"
              />
              {DEMO_VIDEO_ID ? (
                <button
                  type="button"
                  onClick={() => setPlaying(true)}
                  className="mx-auto mt-6 flex items-center gap-3 rounded-full bg-fg py-3 pl-4 pr-6 font-medium text-canvas transition hover:bg-fg/90"
                >
                  <svg viewBox="0 0 16 16" aria-hidden className="size-4 fill-current">
                    <path d="M4 2.5v11L13.5 8Z" />
                  </svg>
                  Play the demo (YouTube)
                </button>
              ) : (
                <>
                  <p className="mt-6 font-display text-heading">The demo video is on its way.</p>
                  <p className="mt-2 text-small text-fg-2">
                    Until then, the Mac at the top of this page runs Pilot’s Brain and
                    commands.json, right here.{' '}
                    <a href="/try" className="text-fg underline underline-offset-4">
                      Try it full size
                    </a>
                  </p>
                </>
              )}
            </div>
          </div>
        )}
      </div>
    </Section>
  );
}

/** My Wispr Flow usage card (public/wispr-usage.png), or a frame waiting for it. */
export function BuiltByVoice() {
  const [missing, setMissing] = useState(false);
  return (
    <Section id="wispr" eyebrow="Built by voice" title="Made with Wispr, for Wispr.">
      <div className="mt-10 grid items-center gap-10 lg:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)]">
        <p className="max-w-[44ch] text-body text-fg-2">
          The specs, prompts and commits for this project were dictated through Wispr Flow. Pilot is
          what I wanted next: the same voice, for everything that isn’t typing.
        </p>
        <Card className={`overflow-hidden ${missing ? 'border-dashed bg-transparent' : ''}`}>
          {missing ? (
            <div className="grid aspect-[16/9] place-items-center p-6 text-center">
              <p className="text-small text-fg-3">My Wispr Flow usage card goes here.</p>
            </div>
          ) : (
            <img
              src="/wispr-usage.png"
              alt="My Wispr Flow usage card"
              loading="lazy"
              onError={() => setMissing(true)}
              className="w-full"
            />
          )}
        </Card>
      </div>
    </Section>
  );
}
