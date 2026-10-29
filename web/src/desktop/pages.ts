// The pages the mock Chrome can show, worked out from the URL alone. All stand-ins, and they say so: no real site
// is loaded or framed. The one real page is this project's README, on the mock GitHub.
import { config } from '../brain/site';

export type Kind =
  'newtab' | 'google' | 'results' | 'youtube' | 'ytresults' | 'watch' | 'github' | 'repo' | 'site';

export interface Video {
  i: number;
  title: string;
  channel: string;
  length: string;
  hue: number;
}
export interface Result {
  title: string;
  url: string;
  text: string;
}
/** Something on the page you can click (or say "click …" to): its name is what "click" matches. */
export interface Item {
  name: string;
  to?: string; // open this URL in the tab
  focus?: true; // the address bar
  play?: true; // the player's button
  link?: string; // a real page, opened in a new browser tab
}
export interface Page {
  kind: Kind;
  url: string;
  title: string;
  host: string;
  query: string;
  length: number; // in screens, for scrolling
  items: Item[];
  results: Result[];
  videos: Video[];
  video?: Video;
}

export const NEW_TAB = 'chrome://newtab';
export const REPO = 'https://github.com/jsuryacodes/nohandspilot';
const enc = encodeURIComponent;
const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

export const googleSearch = (q: string) => `https://www.google.com/search?q=${enc(q)}`;
export const youtubeSearch = (q: string) =>
  `https://www.youtube.com/results?search_query=${enc(q)}`;
const watch = (q: string, i: number) => `https://www.youtube.com/watch?v=${i}&q=${enc(q)}`;

/** What Chrome does with what you typed in the address bar: a web address, or a Google search. */
export function addressTarget(text: string): string {
  const t = text.trim();
  if (/^https?:\/\//i.test(t) || t.startsWith('chrome://')) return t;
  if (/^[\w-]+(\.[\w-]+)+(\/\S*)?$/.test(t)) return `https://${t}`;
  return googleSearch(t);
}

const CHANNELS = [
  'Night Shift Radio',
  'Slow Mornings',
  'Desk Lamp',
  'Field Notes',
  'Small Rooms',
  'Low Light',
];
const SHAPES = ['', ' · 1 hour mix', ', explained', ' (live)', ' for deep work', ' in 10 minutes'];
/** Six stand-in videos for a search. Same query, same videos. */
export function videos(q: string): Video[] {
  const seed = [...q].reduce((h, c) => (h * 31 + c.charCodeAt(0)) % 360, 7);
  return SHAPES.map((shape, i) => ({
    i,
    title: cap(q) + shape,
    channel: CHANNELS[(seed + i) % CHANNELS.length],
    length: `${12 + ((seed + i * 17) % 47)}:${String((seed * (i + 3)) % 60).padStart(2, '0')}`,
    hue: (seed + i * 47) % 360,
  }));
}

function results(q: string): Result[] {
  const tag = q.toLowerCase().trim().replace(/\s+/g, '-');
  return [
    {
      title: `${cap(q)} - Wikipedia`,
      url: `https://en.wikipedia.org/wiki/${enc(cap(q).replace(/ /g, '_'))}`,
      text: `The encyclopedia article on ${q}.`,
    },
    {
      title: `Questions tagged [${tag}] - Stack Overflow`,
      url: `https://stackoverflow.com/questions/tagged/${enc(tag)}`,
      text: `Questions and answers about ${q}.`,
    },
    { title: `${cap(q)} - YouTube`, url: youtubeSearch(q), text: `Videos about ${q}.` },
    {
      title: `${tag} · GitHub Topics`,
      url: `https://github.com/topics/${enc(tag)}`,
      text: `Repositories about ${q}.`,
    },
  ];
}

// New Tab shortcuts: sites from commands.json, by the names you'd say
const TILES: Record<string, string> = {
  youtube: 'YouTube',
  github: 'GitHub',
  gmail: 'Gmail',
  wikipedia: 'Wikipedia',
  'stack overflow': 'Stack Overflow',
  wemakedevs: 'WeMakeDevs',
};
const tiles = (): Item[] =>
  Object.entries(TILES).flatMap(([key, name]) => {
    const site = config.sites?.[key];
    return site ? [{ name, to: site.url }] : [];
  });

export function page(url: string): Page {
  const base = { url, query: '', results: [], videos: [], items: [] as Item[] };
  if (url === NEW_TAB) {
    return {
      ...base,
      kind: 'newtab',
      title: 'New Tab',
      host: '',
      length: 1,
      items: [{ name: 'Search Google or type a URL', focus: true }, ...tiles()],
    };
  }
  let u: URL;
  try {
    u = new URL(url);
  } catch {
    return { ...base, kind: 'site', title: url, host: url, length: 1 };
  }
  const host = u.hostname.replace(/^www\./, '');
  const q = u.searchParams.get('q') ?? u.searchParams.get('search_query') ?? '';
  const ytHeader: Item[] = [
    { name: 'YouTube', to: 'https://www.youtube.com' },
    { name: 'Search', focus: true },
  ];
  if (host === 'google.com' && u.pathname === '/search' && q) {
    const rs = results(q);
    return {
      ...base,
      kind: 'results',
      title: `${q} - Google Search`,
      host,
      query: q,
      length: 2,
      results: rs,
      items: [
        { name: 'Google', to: 'https://www.google.com' },
        { name: 'Search', focus: true },
        ...rs.map((r) => ({ name: r.title, to: r.url })),
      ],
    };
  }
  if (host === 'google.com') {
    return {
      ...base,
      kind: 'google',
      title: 'Google',
      host,
      length: 1,
      items: [{ name: 'Search', focus: true }],
    };
  }
  if (host === 'youtube.com' && u.pathname === '/results' && q) {
    const vs = videos(q);
    return {
      ...base,
      kind: 'ytresults',
      title: `${q} - YouTube`,
      host,
      query: q,
      length: 2.5,
      videos: vs,
      items: [...ytHeader, ...vs.map((v) => ({ name: v.title, to: watch(q, v.i) }))],
    };
  }
  if (host === 'youtube.com' && u.pathname === '/watch') {
    const vs = videos(q || 'lofi beats');
    const video = vs[Number(u.searchParams.get('v')) || 0] ?? vs[0];
    const next = vs.filter((v) => v !== video);
    return {
      ...base,
      kind: 'watch',
      title: `${video.title} - YouTube`,
      host,
      query: q,
      length: 1.8,
      video,
      videos: next,
      items: [
        ...ytHeader,
        { name: 'player', play: true },
        ...next.map((v) => ({ name: v.title, to: watch(q, v.i) })),
      ],
    };
  }
  if (host === 'youtube.com') {
    const vs = videos('lofi beats')
      .slice(0, 2)
      .concat(videos('docker networking').slice(1, 3), videos('swift').slice(2, 4));
    return {
      ...base,
      kind: 'youtube',
      title: 'YouTube',
      host,
      length: 2,
      videos: vs,
      items: [...ytHeader, ...vs.map((v) => ({ name: v.title, to: watch(v.title, 0) }))],
    };
  }
  if (host === 'github.com' && u.pathname.replace(/\/$/, '') === '/jsuryacodes/nohandspilot') {
    return {
      ...base,
      kind: 'repo',
      title: 'jsuryacodes/nohandspilot',
      host,
      length: 3,
      items: [
        { name: 'GitHub', to: 'https://github.com' },
        { name: 'Releases', link: `${REPO}/releases/latest` },
        { name: 'Open on GitHub', link: REPO },
      ],
    };
  }
  if (host === 'github.com' && (u.pathname === '/' || u.pathname === '')) {
    return {
      ...base,
      kind: 'github',
      title: 'GitHub',
      host,
      length: 1,
      items: [
        { name: 'GitHub', to: 'https://github.com' },
        { name: 'jsuryacodes/nohandspilot', to: REPO },
      ],
    };
  }
  return { ...base, kind: 'site', title: host, host, length: 1 };
}
