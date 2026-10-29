// Original app icons for the mock Dock: a tile and a generic glyph, labelled with the app's name elsewhere.
// None of them is the real app's icon or logo.
import { useId } from 'react';
import type { App } from '../brain/site';

const TILES: Record<
  Exclude<App, 'NoHandsPilot'>,
  { from: string; to: string; ink: string; glyph: React.ReactNode }
> = {
  Finder: {
    from: '#6aaef0',
    to: '#2f6cc9',
    ink: '#fff',
    glyph: <path d="M15 21h11l4 4.5h19v19.5a4 4 0 0 1-4 4H19a4 4 0 0 1-4-4Z" fill="currentColor" />,
  },
  'Google Chrome': {
    from: '#eef2f6',
    to: '#c3ced8',
    ink: '#24384d',
    glyph: (
      <g fill="none" stroke="currentColor" strokeWidth="3">
        <circle cx="32" cy="32" r="16" />
        <path d="M16 32h32M32 16c-6 5-6 27 0 32M32 16c6 5 6 27 0 32" />
      </g>
    ),
  },
  'Visual Studio Code': {
    from: '#2f8d9c',
    to: '#174c57',
    ink: '#fff',
    glyph: (
      <path
        d="m24 22-10 10 10 10M40 22l10 10-10 10M35 18l-6 28"
        fill="none"
        stroke="currentColor"
        strokeWidth="3.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    ),
  },
  Claude: {
    from: '#efe2cf',
    to: '#cdb08d',
    ink: '#3b2c1f',
    glyph: (
      <g fill="currentColor">
        <path
          d="M17 20a5 5 0 0 1 5-5h20a5 5 0 0 1 5 5v15a5 5 0 0 1-5 5H29l-8 7v-7h1a5 5 0 0 1-5-5Z"
          fillOpacity=".9"
        />
      </g>
    ),
  },
  Terminal: {
    from: '#41444a',
    to: '#121315',
    ink: '#e9e9e9',
    glyph: (
      <path
        d="m18 24 8 7-8 7M30 41h14"
        fill="none"
        stroke="currentColor"
        strokeWidth="3.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    ),
  },
  Music: {
    from: '#c2547a',
    to: '#7a2848',
    ink: '#fff',
    glyph: (
      <g fill="currentColor">
        <path d="M27 18 45 14v22.5a5 5 0 1 1-3-4.6V21.2l-12 2.6v16.7a5 5 0 1 1-3-4.6Z" />
      </g>
    ),
  },
  'System Settings': {
    from: '#b5bac0',
    to: '#6d737b',
    ink: '#fff',
    glyph: (
      <g fill="none" stroke="currentColor" strokeWidth="3.2">
        <circle cx="32" cy="32" r="6" />
        <path
          d="M32 14v6M32 44v6M14 32h6M44 32h6M19.3 19.3l4.2 4.2M40.5 40.5l4.2 4.2M19.3 44.7l4.2-4.2M40.5 23.5l4.2-4.2"
          strokeLinecap="round"
        />
        <circle cx="32" cy="32" r="13" />
      </g>
    ),
  },
};

export function AppIcon({ app, className }: { app: App; className?: string }) {
  const id = useId();
  if (app === 'NoHandsPilot')
    return <img src="/favicon.svg" alt="" draggable={false} className={className} />;
  const t = TILES[app];
  return (
    <svg viewBox="0 0 64 64" aria-hidden className={className} style={{ color: t.ink }}>
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={t.from} />
          <stop offset="1" stopColor={t.to} />
        </linearGradient>
      </defs>
      <rect width="64" height="64" rx="14.5" fill={`url(#${id})`} />
      <rect
        x=".5"
        y=".5"
        width="63"
        height="63"
        rx="14"
        fill="none"
        stroke="#fff"
        strokeOpacity=".18"
      />
      {t.glyph}
    </svg>
  );
}

const stroke = {
  fill: 'none',
  stroke: 'currentColor',
  strokeLinecap: 'round',
  strokeLinejoin: 'round',
} as const;

/** Pilot's menu-bar icon is an airplane (setup.md); this one is drawn from scratch. */
export const Airplane = ({ className }: { className?: string }) => (
  <svg viewBox="0 0 16 16" aria-hidden className={className} fill="currentColor">
    <path d="M7.2 1.6c.2-.5.8-.5 1 0 .2.4.3 1 .3 1.6v3l5.3 3v1.4l-5.3-1.6v3l1.6 1.2V15L8 14.3 5.9 15v-1.8l1.6-1.2v-3L2.2 10.6V9.2l5.3-3v-3c0-.6.1-1.2.3-1.6Z" />
  </svg>
);

export const WifiGlyph = ({ className }: { className?: string }) => (
  <svg viewBox="0 0 16 16" aria-hidden className={className} {...stroke} strokeWidth="1.5">
    <path d="M2 6.2a8.6 8.6 0 0 1 12 0M4.2 8.6a5.4 5.4 0 0 1 7.6 0M6.4 11a2.2 2.2 0 0 1 3.2 0" />
    <circle cx="8" cy="13" r=".6" fill="currentColor" />
  </svg>
);

export const BatteryGlyph = ({ className }: { className?: string }) => (
  <svg viewBox="0 0 24 12" aria-hidden className={className}>
    <rect
      x=".75"
      y=".75"
      width="19.5"
      height="10.5"
      rx="3"
      fill="none"
      stroke="currentColor"
      strokeOpacity=".5"
      strokeWidth="1.2"
    />
    <rect x="2.5" y="2.5" width="13" height="7" rx="1.6" fill="currentColor" />
    <path
      d="M22 4.2v3.6c.8-.3 1.2-1 1.2-1.8s-.4-1.5-1.2-1.8Z"
      fill="currentColor"
      fillOpacity=".5"
    />
  </svg>
);

export const MicGlyph = ({ className }: { className?: string }) => (
  <svg viewBox="0 0 16 16" aria-hidden className={className} {...stroke} strokeWidth="1.5">
    <rect x="5.5" y="1.75" width="5" height="8.5" rx="2.5" />
    <path d="M3 7.5a5 5 0 0 0 10 0M8 12.5v2" />
  </svg>
);

/** Small glyphs for the mock apps' toolbars. */
export const Glyph = {
  back: 'M10 3 5 8l5 5',
  forward: 'm6 3 5 5-5 5',
  reload: 'M13 8a5 5 0 1 1-1.5-3.6M13 2.5v3h-3',
  plus: 'M8 3v10M3 8h10',
  close: 'm4.5 4.5 7 7m0-7-7 7',
  search: 'M7 12A5 5 0 1 0 7 2a5 5 0 0 0 0 10ZM10.6 10.6 14 14',
  play: 'M5 3.2v9.6L13 8Z',
  pause: 'M5 3v10M11 3v10',
  folder: 'M2 4.5h4l1.5 1.5H14V12a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1Z',
  file: 'M4 1.5h5.5L12.5 4.5V14a.5.5 0 0 1-.5.5H4a.5.5 0 0 1-.5-.5V2a.5.5 0 0 1 .5-.5ZM9.5 1.5v3h3',
  files: 'M3 2h6l3 3v9H3ZM9 2v3h3',
  chat: 'M2.5 4a1.5 1.5 0 0 1 1.5-1.5h8A1.5 1.5 0 0 1 13.5 4v5.5A1.5 1.5 0 0 1 12 11H7l-3 2.5V11a1.5 1.5 0 0 1-1.5-1.5Z',
  send: 'M8 13V3M3.5 7.5 8 3l4.5 4.5',
  sidebar: 'M2 3h12v10H2ZM6 3v10',
};
export const Icon = ({ d, className = 'size-4' }: { d: string; className?: string }) => (
  <svg viewBox="0 0 16 16" aria-hidden className={className} {...stroke} strokeWidth="1.5">
    <path d={d} />
  </svg>
);
