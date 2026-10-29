// Every command the landing page shows, in one place, so a test can check that the real Brain runs each one.

/** Things I used to do by hand, and what I say instead. */
export const BEFORE_AFTER = [
  { task: 'Open an app', hand: '⌘Space, type “Chrome”, ↩', said: 'Pilot, open Chrome' },
  {
    task: 'Search the web',
    hand: '⌘T, type the query, ↩',
    said: 'Pilot, search for Docker networking',
  },
  { task: 'Switch tabs', hand: '⌃⇥, and again, and again', said: 'Pilot, go to tab three' },
  { task: 'Click a button', hand: 'Find the pointer, aim, click', said: 'Pilot, click Sign in' },
  { task: 'Scroll a page', hand: 'Two fingers on the trackpad', said: 'Pilot, scroll down' },
  { task: 'Pause a video', hand: 'Find the player, click it', said: 'Pilot, pause the video' },
];

export const CHAIN = 'Pilot, open Chrome, new tab, search for Docker networking';
export const TEACH = 'Pilot, when I say focus time, do open Notion, mute';
export const TAUGHT = 'Pilot, focus time';
export const TEACH_THAT = 'Pilot, teach that: new tab';

/** What the hero's Mac plays, round and round, until you take over. */
export const HERO_SHOW = [
  'open Chrome, new tab, search for Docker networking',
  'play lofi beats on YouTube',
  'show numbers',
  'click 3',
  'pause the video',
  'study mode',
];
