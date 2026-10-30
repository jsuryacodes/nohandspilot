// Every case from app/Sources/BrainCheck/main.swift, against the real commands.json, in the same order.
import commands from '@commands';
import { beforeAll, describe, expect, test } from 'vitest';
import { Brain, type Action, type Config, type Plan } from './brain';

// prettier-ignore
const profiles: [string, string][] = [
  ['Jaya', 'Default'], ['College', 'Profile 1'], ['Jaya Surya', 'Profile 2'], ['Work', 'Profile 9'],
  ['Jaya Surya', 'Default'], ['PENUMATCHA JAYA SURYA', 'Profile 1'], ['Jaya Surya Penumatcha', 'Profile 2'],
];
// prettier-ignore
const brain = new Brain(
  commands as Config,
  ['Google Chrome', 'Claude', 'Visual Studio Code', 'Finder', 'Telegram', 'WhatsApp', 'Safari', 'Terminal',
    'GitHub Desktop', 'YouTube', 'ChatGPT', 'Spotify', 'Music', 'Numbers Creator Studio', 'OBS', 'Time Machine'],
  { 'OBS Studio': 'OBS', Numbers: 'Numbers Creator Studio', Code: 'Visual Studio Code' },
  {
    profile: profiles,
    folder: [['downloads', '/Users/me/Downloads'], ['documents', '/Users/me/Documents'], ['home', '/Users/me'],
      ['applications', '/Applications']],
  },
);

function actions(b: Brain, text: string, app?: string, trigger = true): Action[] | undefined {
  const plan = b.plan(text, app, { requireTrigger: trigger });
  return plan.kind === 'run' ? plan.steps.flatMap((s) => s.actions) : undefined;
}
function check(
  text: string,
  expected: Action[] | undefined,
  { app, trigger = true }: { app?: string; trigger?: boolean } = {},
) {
  test(`"${text}" [${app ?? '-'}]`, () =>
    expect(actions(brain, text, app, trigger)).toEqual(expected));
}
function expectPlan(text: string, plan: Plan) {
  test(`"${text}"`, () => expect(brain.plan(text)).toEqual(plan));
}

const openApp = (app: string): Action => ({ kind: 'openApp', app });
const quitApp = (app: string): Action => ({ kind: 'quitApp', app });
const keys = (k: string): Action => ({ kind: 'keys', keys: k });
const typed = (text: string): Action => ({ kind: 'type', text });
const scroll = (direction: string, amount = 6): Action => ({ kind: 'scroll', direction, amount });
const url = (u: string): Action => ({ kind: 'openURL', url: u });
const media = (key: string): Action => ({ kind: 'media', key });
const wait = (ms: number): Action => ({ kind: 'wait', ms });
const click = (target: string): Action => ({ kind: 'click', target });
const numbers = (show: boolean): Action => ({ kind: 'numbers', show });
const playMusic = (query: string): Action => ({ kind: 'playMusic', query });
const profile = (p: string): Action => ({ kind: 'chromeProfile', profile: p });
const menu = (app: string, path: string[]): Action => ({ kind: 'menu', app, path });
const listen = (on: boolean): Action => ({ kind: 'listen', on });
const dictate: Action = { kind: 'dictate' };
const openFile = (name: string, folder: boolean, reveal: boolean): Action => ({
  kind: 'openFile',
  name,
  folder,
  reveal,
});
const chrome = openApp('Google Chrome');
const wa = openApp('WhatsApp');

describe('trigger handling: punctuation, case, "hey", no trigger', () => {
  check('Pilot, open Chrome.', [chrome]);
  check('pilot open chrome', [chrome]);
  check('  Hey, Pilot: launch Visual Studio Code!', [openApp('Visual Studio Code')]);
  check('Open Chrome.', undefined);
  test('non-Pilot text is notForPilot', () =>
    expect(brain.plan('Open Chrome.')).toEqual({ kind: 'notForPilot' }));
  check('Pilots are great', undefined);
  check('Pilot programs are useful.', undefined);
  check('open chrome', [chrome], { trigger: false });
});

describe('sentences from the real usage log (28 Oct)', () => {
  check('Pilot, open Chrome in a new tab and search "hello". ', [
    chrome,
    keys('cmd+t'),
    keys('cmd+l'),
    typed('hello'),
    keys('enter'),
  ]);
  check('Pilot, open Chrome and search hello. ', [
    chrome,
    keys('cmd+l'),
    typed('hello'),
    keys('enter'),
  ]);
  check('Pilot, can you switch the Chrome profile to Jaya Surya Penumatcha? ', [
    profile('Profile 2'),
  ]);
  check('Pilot, can you switch the Chrome profile to Jaya Surya? ', [profile('Profile 2')]);
  check('Pilot, can you open a new Chrome tab? ', [chrome, keys('cmd+t')]);
  check('Pilot, open a new Chrome tab. ', [chrome, keys('cmd+t')]);
  check(
    'open chrome , open a new tab and search hello',
    [chrome, keys('cmd+t'), keys('cmd+l'), typed('hello'), keys('enter')],
    { trigger: false },
  );
});

describe('profiles', () => {
  check('Pilot, switch to my college profile', [profile('Profile 1')]);
  check('Pilot, switch to work profile', [profile('Profile 9')], { app: 'Finder' });
  check('Pilot, change chrome profile to Jaya', [profile('Default')]);
});

describe('fuzzy app names, strict quit', () => {
  check('Pilot, switch to telegrm', [openApp('Telegram')]);
  check('Pilot, open VS Code', [openApp('Visual Studio Code')]);
  check('Pilot, quit chrome', [quitApp('Google Chrome')]);
  check('Pilot, quit chrom', undefined);
});

describe('sites and search', () => {
  check('Pilot, open GitHub', [url('https://github.com')]);
  check('Pilot, go to docker.com', [url('https://docker.com')]);
  check('Pilot, search YouTube for lofi music', [
    url('https://www.youtube.com/results?search_query=lofi%20music'),
  ]);
  check('Pilot, play lofi beats on YouTube', [
    url('https://www.youtube.com/results?search_query=lofi%20beats'),
  ]);
  check('Pilot, search for docker networking on stack overflow', [
    url('https://stackoverflow.com/search?q=docker%20networking'),
  ]);
  check(
    'Pilot, search for docker in chrome',
    [chrome, keys('cmd+l'), typed('docker'), keys('enter')],
    { app: 'Finder' },
  );
  check('Pilot, search for docker', [chrome, keys('cmd+t'), typed('docker'), keys('enter')], {
    app: 'Terminal',
  });
  check(
    'Pilot, search for chrome extensions',
    [keys('cmd+l'), typed('chrome extensions'), keys('enter')],
    { app: 'Google Chrome' },
  );
  check('Pilot, ask Claude what is a docker bridge network', [
    openApp('Claude'),
    keys('cmd+n'),
    wait(600),
    typed('what is a docker bridge network'),
    wait(100),
    keys('enter'),
  ]);
});

describe('chains', () => {
  check('Pilot, open Chrome, new tab, search for Docker networking.', [
    chrome,
    keys('cmd+t'),
    keys('cmd+l'),
    typed('Docker networking'),
    keys('enter'),
  ]);
  check('Pilot open chrome then new tab and then scroll down', [
    chrome,
    keys('cmd+t'),
    scroll('down'),
  ]);
  check('Pilot, scroll right', [scroll('right')]);
  check('Pilot, scroll to the left.', [scroll('left')]);
  // "… across space" moves between full-screen apps and desktops; plain "scroll" stays in the app
  check('Pilot, scroll right across space', [keys('ctrl+right')]);
  check('Pilot, scroll to the left across spaces.', [keys('ctrl+left')]);
  check('Pilot, scroll up across the space', [keys('ctrl+up')]);
  check('Pilot, scroll down across spaces', [keys('ctrl+down')]);
  check(
    'Pilot, search for salt and pepper',
    [keys('cmd+l'), typed('salt and pepper'), keys('enter')],
    { app: 'Google Chrome' },
  );
  check('Pilot, open chrome, blorp, new tab', undefined);
  check('Pilot, open YouTube website, then scroll down a lot', [
    url('https://www.youtube.com'),
    scroll('down', 16),
  ]);
});

describe('per-app commands, "in <app>", app named mid-sentence, filler words', () => {
  check('Pilot, toggle the sidebar', [keys('cmd+b')], { app: 'Visual Studio Code' });
  check('Pilot, toggle sidebar', [keys('ctrl+cmd+s')], { app: 'Finder' });
  check('Pilot, open the sidebar in Claude', [openApp('Claude'), keys('cmd+b')]);
  check('Pilot, close the Claude sidebar', [openApp('Claude'), keys('cmd+b')]);
  check('Pilot, um, can you please open a new tab for me', [keys('cmd+t')], {
    app: 'Google Chrome',
  });
  check('Pilot, I want to go back', [keys('cmd+[')], { app: 'Google Chrome' });
  check('Pilot, open the terminal in VS Code', [openApp('Visual Studio Code'), keys('ctrl+`')]);
  check('Pilot, go to tab three', [keys('cmd+3')], { app: 'Google Chrome' });
  check('Pilot, switch to the last tab', [keys('cmd+9')], { app: 'Google Chrome' });
});

describe('commands aimed at an app stay in that app (real miss, 28 Oct)', () => {
  check('Pilot, can you search Jotir Aditya in WhatsApp? ', [
    wa,
    keys('cmd+f'),
    wait(250),
    typed('Jotir Aditya'),
  ]);
  check('Pilot, search jyothir aditya on whatsapp', [
    wa,
    keys('cmd+f'),
    wait(250),
    typed('jyothir aditya'),
  ]);
  check('Pilot, search for Jyothir', [keys('cmd+f'), wait(250), typed('Jyothir')], {
    app: 'WhatsApp',
  });
  check('Pilot, search for notes in Telegram', [
    openApp('Telegram'),
    keys('cmd+f'),
    wait(150),
    typed('notes'),
  ]);
  check('Pilot, open GitHub in Chrome', [url('https://github.com')]);
});

describe('chains stay in the app they switched to; display names; reserved phrases (real misses, 28 Oct)', () => {
  check('Pilot, can you open music and search Florida?', [
    openApp('Music'),
    keys('cmd+f'),
    wait(250),
    typed('Florida'),
    keys('enter'),
  ]);
  check('Pilot, search for Florida', [keys('cmd+f'), wait(250), typed('Florida'), keys('enter')], {
    app: 'Music',
  });
  // "play X" plays in Music (30 Oct): "apple music" is the Music app; site search and bare play/pause are unchanged
  const music = openApp('Music');
  check('Pilot, play Florida on Apple Music', [music, playMusic('Florida')]);
  check('Pilot, play Florida in Music', [music, playMusic('Florida')], { app: 'Google Chrome' });
  check('Pilot, play Florida on music', [music, playMusic('Florida')]);
  check('Pilot, play Florida', [playMusic('Florida')], { app: 'Music' });
  check('Pilot, play the song Florida on Apple Music', [music, playMusic('the song Florida')]); // Hands drops "the song"
  check('Pilot, play', [media('play')], { app: 'Music' });
  check('Pilot, pause', [media('pause')], { app: 'Music' });
  check(
    'Pilot, play lofi beats on YouTube',
    [url('https://www.youtube.com/results?search_query=lofi%20beats')],
    { app: 'Music' },
  );
  check('Pilot, search for Florida on Apple Music', [
    music,
    keys('cmd+f'),
    wait(250),
    typed('Florida'),
    keys('enter'),
  ]); // search stays search
  check('Pilot, open Apple Music', [music]);
  check('Pilot, open finder, search for report', [
    openApp('Finder'),
    keys('cmd+f'),
    wait(150),
    typed('report'),
  ]);
  check('Pilot, open chrome, ask claude what is jazz', [
    chrome,
    openApp('Claude'),
    keys('cmd+n'),
    wait(600),
    typed('what is jazz'),
    wait(100),
    keys('enter'),
  ]);
  check('Pilot, open chrome, open claude', [chrome, openApp('Claude')]);
  check('Pilot, can you open OBS Studio?', [openApp('OBS')]);
  check('Pilot, open numbers', [openApp('Numbers Creator Studio')]);
  check('Pilot, show numbers.', [numbers(true)]);
});

describe('misc', () => {
  check('Pilot, pause the music', [media('pause')]);
  check('Pilot, pause the video.', [media('pause')]); // real misses, 29 Oct: no video phrases
  check('Pilot, resume video', [media('play')]);
  check('Pilot, play video', [media('play')]);
  check('Pilot, stop the video', [media('pause')]);
  check('Pilot, play', [media('play')]);
  check('Pilot, play pause', [media('playPause')]);
  check('Pilot, show number', [numbers(true)]); // real miss, 29 Oct: opened the Numbers app
  check('Pilot, hide number', [numbers(false)]);
  check('Pilot, open Bluetooth', [url('x-apple.systempreferences:com.apple.BluetoothSettings')]);
  check('Pilot, open Wi-Fi', [url('x-apple.systempreferences:com.apple.wifi-settings-extension')]);
  check('Pilot, open network settings', [
    url('x-apple.systempreferences:com.apple.Network-Settings.extension'),
  ]);
  check('Pilot, open Spotlight', [keys('cmd+space')]); // real miss, 29 Oct: waited 5 s for a Spotlight app
  check('Pilot, turn up the volume', [media('volumeUp')]);
  check('Pilot, switch back', [{ kind: 'previousApp' }]);
  check('Pilot, type hello, how are you', [typed('hello, how are you')]);
  check(
    'Pilot, search for the best pizza',
    [keys('cmd+l'), typed('the best pizza'), keys('enter')],
    { app: 'Google Chrome' },
  );
  check('Pilot, study mode', [chrome, keys('cmd+t'), openApp('Claude'), keys('cmd+n')]);
  test('a miss comes with a suggestion', () => {
    const plan = brain.plan('Pilot, open a fresh tab', 'Google Chrome');
    expect(plan.kind === 'unmatched' && plan.suggestion).toBeTruthy();
  });
  check('Pilot, can you reduce the volume?', [media('volumeDown')]); // real miss, 28 Oct
});

// From here on the brain reads the current app's menus, as in BrainCheck (rule 8)
describe('menu items of the current app (rule 8): only after every rule misses, exact titles only', () => {
  beforeAll(() => {
    brain.menuItems = (app) =>
      app === 'Google Chrome'
        ? [
            ['File', 'Export as PDF…'],
            ['Tab', 'Duplicate Tab'],
            ['View', 'Developer', 'View Source'],
            ['Bookmarks', 'Bookmarks & Lists'],
            ['File', 'New Tab'],
          ]
        : [];
  });
  const dupTab = menu('Google Chrome', ['Tab', 'Duplicate Tab']);
  check('Pilot, duplicate the tab.', [dupTab], { app: 'Google Chrome' });
  check('Pilot, export as PDF', [menu('Google Chrome', ['File', 'Export as PDF…'])], {
    app: 'Google Chrome',
  });
  check('Pilot, view source', [menu('Google Chrome', ['View', 'Developer', 'View Source'])], {
    app: 'Google Chrome',
  });
  check('Pilot, bookmarks and lists', [menu('Google Chrome', ['Bookmarks', 'Bookmarks & Lists'])], {
    app: 'Google Chrome',
  });
  check('Pilot, open chrome, duplicate tab', [chrome, dupTab], { app: 'Finder' }); // the app the chain switched to
  check('Pilot, new tab', [keys('cmd+t')], { app: 'Google Chrome' }); // rules first
  check('Pilot, type hello, duplicate tab', [typed('hello, duplicate tab')], {
    app: 'Google Chrome',
  }); // rule 7 first
  check('Pilot, duplicate', undefined, { app: 'Google Chrome' }); // no prefixes
  check('Pilot, duplicate tab', undefined, { app: 'Finder' }); // only that app's menus
  check('Pilot programs are useful.', undefined, { app: 'Google Chrome' });
});

describe('click by name (1b): the target is normalised; literal phrases still win', () => {
  check('Pilot, click Sign in', [click('sign in')]);
  check('Pilot, click on the Send button.', [click('send button')]);
  check('Pilot, tap Downloads', [click('downloads')]);
  check('Pilot, choose English', [click('english')]);
  check('Pilot, press play', [click('play')]);
  check('Pilot, click send in WhatsApp', [wa, click('send')]);
  check('Pilot, click sign in, then scroll down', [click('sign in'), scroll('down')]);
  check('Pilot, press enter', [keys('enter')]);
  check('Pilot, press the enter key', [keys('enter')]);
  check('Pilot, press escape', [keys('esc')]);
  check('Pilot, select all', [keys('cmd+a')]);
  check('Pilot, select everything', [keys('cmd+a')]);
});

describe('select, copy, cut and delete (31 Oct): keyboard edits work anywhere and chain', () => {
  const optLeft = keys('opt+shift+left');
  check('Pilot, select word', [optLeft]);
  check('Pilot, select the last word', [optLeft]);
  check('Pilot, select last 3 words', [optLeft, optLeft, optLeft]);
  check('Pilot, select the last three words, cut', [optLeft, optLeft, optLeft, keys('cmd+x')]);
  check('Pilot, select line', [keys('cmd+left'), keys('cmd+shift+right')]);
  check('Pilot, select to the start of the line', [keys('cmd+shift+left')]);
  check('Pilot, select to end of line', [keys('cmd+shift+right')]);
  check('Pilot, select paragraph', [keys('opt+up'), keys('opt+shift+down')]);
  check('Pilot, cut', [keys('cmd+x')]);
  check('Pilot, cut that', [keys('cmd+x')]);
  check('Pilot, cut it', [keys('cmd+x')]);
  check('Pilot, copy that', [keys('cmd+c')]);
  check('Pilot, copy', [keys('cmd+c')]);
  check('Pilot, delete that', [keys('delete')]);
  check('Pilot, delete it', [keys('delete')]);
  check('Pilot, delete selection', [keys('delete')]);
  check('Pilot, delete word', [keys('opt+delete')]);
  check('Pilot, delete the last 2 words', [keys('opt+delete'), keys('opt+delete')]);
  check('Pilot, delete line', [keys('cmd+delete')]);
  check('Pilot, redo', [keys('cmd+shift+z')]);
  check('Pilot, undo', [keys('cmd+z')]);
  check('Pilot, paste', [keys('cmd+v')]);
  // screenshots (31 Oct): taken as before; "paste the screenshot" pastes the latest, plain "paste" stays your clipboard
  const shot: Action = { kind: 'pasteScreenshot' };
  check('Pilot, take a screenshot', [keys('cmd+shift+3')]);
  check('Pilot, paste the screenshot', [shot]);
  check('Pilot, paste my last screenshot', [shot]);
  check('Pilot, take a screenshot, paste the screenshot', [keys('cmd+shift+3'), shot]);
  check('Pilot, paste it', [keys('cmd+v')]);
});

describe('links: by name like click (a badge number while numbers are up); the page address in Chrome', () => {
  const copyLink = (target: string): Action => ({ kind: 'copyLink', target });
  check('Pilot, copy link Docs', [copyLink('docs')]);
  check('Pilot, copy the Docs link', [copyLink('docs')]);
  check('Pilot, copy link 2', [copyLink('2')]);
  check('Pilot, copy link number two', [copyLink('2')]);
  const pageLink = [keys('cmd+l'), keys('cmd+c'), wait(100), keys('esc')];
  check('Pilot, copy page link', pageLink, { app: 'Google Chrome' });
  check('Pilot, copy this link', pageLink, { app: 'Google Chrome' });
  check('Pilot, copy the URL', pageLink, { app: 'Google Chrome' });
});

describe('a phrase in the focused text field; "select X" outside one is still a click', () => {
  const sel = (phrase: string, op: string, click: string): Action => ({
    kind: 'selectText',
    phrase,
    op,
    click,
  });
  check('Pilot, select hello world', [sel('hello world', 'select', 'hello world')]);
  check('Pilot, select Downloads', [sel('Downloads', 'select', 'downloads')]);
  check('Pilot, select 3', [sel('3', 'select', '3')]);
  check('Pilot, delete the quick brown fox', [
    sel('the quick brown fox', 'delete', 'quick brown fox'),
  ]);
  check('Pilot, cut see you soon', [sel('see you soon', 'cut', 'see you soon')]);
  check('Pilot, copy my address', [sel('my address', 'copy', 'address')]);
  check('Pilot, select all', [keys('cmd+a')]); // still select all
});

describe('show numbers (1c): numbers go to click as digits; "close/hide numbers" never touches the Numbers app', () => {
  check('Pilot, show labels', [numbers(true)]);
  check('Pilot, hide numbers', [numbers(false)]);
  check('Pilot, close numbers', [numbers(false)]);
  check('Pilot, click 12', [click('12')]);
  check('Pilot, click twelve', [click('12')]);
  check('Pilot, number 7', [click('7')]);
  check('Pilot, click number twenty-one', [click('21')]);
  check('Pilot, click a hundred and five', [click('105')]);
  check('Pilot, click #3.', [click('3')]);
  check('Pilot, show numbers, click 4', [numbers(true), click('4')]);
  // a tie numbers just the tied matches (30 Oct); Hands reads these while badges are up
  check('Pilot, click the second one', [click('second one')]);
  check('Pilot, click the last one', [click('last one')]);
  check('Pilot, click the first one.', [click('first one')]);
});

describe('no hands: wake word on/off, dictation', () => {
  check('Pilot, start listening.', [listen(true)]);
  check('Pilot, stop listening', [listen(false)]);
  check('start listening', [listen(true)], { trigger: false });
  check('Pilot, dictate', [dictate]);
  check('Dictate.', [dictate], { trigger: false });
  check('Pilot, start dictation', [dictate]);
  // Wispr's text without punctuation
  check('Pilot scroll right across space', [keys('ctrl+right')]);
  check('Pilot dictate', [dictate]);
  check('Pilot open Chrome then new tab', [chrome, keys('cmd+t')]);
  check('Pilot open Chrome new tab', [chrome, keys('cmd+t')]);
});

describe('teaching (rule 1b): parsed before chain splitting; taught phrases then match like macros', () => {
  expectPlan('Pilot, when I say focus time, do open Notion, mute.', {
    kind: 'teach',
    phrase: 'focus time',
    commands: ['open Notion', 'mute'],
  });
  expectPlan('Pilot, when I say "good night," run lock screen', {
    kind: 'teach',
    phrase: 'good night',
    commands: ['lock screen'],
  });
  expectPlan('Pilot, when I say do not disturb, do mute', {
    kind: 'teach',
    phrase: 'do not disturb',
    commands: ['mute'],
  });
  expectPlan('Pilot, teach that: new tab', { kind: 'teach', commands: ['new tab'] });
  expectPlan('Pilot, that means open a new tab, then scroll down.', {
    kind: 'teach',
    commands: ['open a new tab', 'scroll down'],
  });
  expectPlan('Pilot, forget focus time.', { kind: 'forget', phrase: 'focus time' });
  check('Pilot, focus time', [openApp('Time Machine')]); // "focus" = "switch to", "time" = unique prefix (typo pass)
  test('without typos, "focus time" is free to teach', () =>
    expect(brain.plan('focus time', undefined, { requireTrigger: false, typos: false }).kind).toBe(
      'unmatched',
    ));
  test('a taught phrase runs like a macro', () => {
    const config = commands as Config;
    const taught = new Brain(
      { ...config, macros: { ...config.macros, 'focus time': ['mute', 'full screen'] } },
      ['Time Machine'],
    );
    expect(actions(taught, 'Pilot, focus time.')).toEqual([media('mute'), keys('ctrl+cmd+f')]);
  });
});

describe('open anything by name (3): needs a file/folder word; known folders from any app; Settings panes', () => {
  const downloads = openFile('/Users/me/Downloads', true, false);
  check('Pilot, open downloads', [downloads], { app: 'Google Chrome' });
  check('Pilot, open the downloads folder', [downloads]);
  check('Pilot, open downloads', [keys('cmd+opt+l')], { app: 'Finder' }); // Finder's own command wins in Finder
  check('Pilot, open home folder', [openFile('/Users/me', true, false)]);
  check('Pilot, open file my resume', [openFile('resume', false, false)]);
  check('Pilot, open the hackathon folder', [openFile('hackathon', true, false)]);
  check('Pilot, show resume.pdf in Finder', [openFile('resume.pdf', false, true)]);
  check('Pilot, find file budget 2026', [openFile('budget 2026', false, false)]);
  check('Pilot, open file report', [keys('cmd+p'), wait(200), typed('report')], {
    app: 'Visual Studio Code',
  }); // VS Code's quick open there
  check('Pilot, open resume', undefined); // no file word: never a file search
  check('Pilot, open bluetooth settings', [
    url('x-apple.systempreferences:com.apple.BluetoothSettings'),
  ]);
  check('Pilot, Wi-Fi settings.', [
    url('x-apple.systempreferences:com.apple.wifi-settings-extension'),
  ]);
  check('Pilot, open privacy and security settings', [
    url('x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension'),
  ]);
  check('Pilot, open settings', [openApp('System Settings')]);
});

describe('selected text (4): "this" is a filler, so free text needs a real word; {selection} is filled in at run time', () => {
  const searchSel = url('https://www.google.com/search?q={selection}');
  const askSel = [
    openApp('Claude'),
    keys('cmd+n'),
    wait(600),
    typed('{selection}'),
    wait(100),
    keys('enter'),
  ];
  check('Pilot, search this', [searchSel]);
  check('Pilot, search this.', [searchSel], { app: 'Google Chrome' }); // not Chrome's own "search for {query}"
  check('Pilot, google this', [searchSel], { app: 'Visual Studio Code' });
  check('Pilot, translate this', [
    url('https://translate.google.com/?sl=auto&tl=en&text={selection}&op=translate'),
  ]);
  check('Pilot, define this', [url('dict://{selection}')]);
  check('Pilot, what does this mean?', [url('dict://{selection}')]);
  check('Pilot, ask Claude about this', askSel);
  check('Pilot, ask Claude about this', askSel, { app: 'Claude' }); // not Claude's own "ask {query}"
  check('Pilot, ask Claude about black holes', [
    openApp('Claude'),
    keys('cmd+n'),
    wait(600),
    typed('black holes'),
    wait(100),
    keys('enter'),
  ]);
  check(
    "Pilot, search for this week's news",
    [keys('cmd+l'), typed("this week's news"), keys('enter')],
    { app: 'Google Chrome' },
  );
  check('Pilot, type the', undefined); // free text needs one real word
});

describe('wake word (30 Oct): only Wispr\'s text runs, never Apple\'s words; a leading "Pilot" Wispr caught is dropped', () => {
  const woke = (wispr: string, expected: Action[] | undefined) =>
    test(wispr, () =>
      expect(actions(brain, brain.wakeCommand(wispr), undefined, false)).toEqual(expected),
    );
  woke('Open Chrome, new tab, search for Docker networking.', [
    chrome,
    keys('cmd+t'),
    keys('cmd+l'),
    typed('Docker networking'),
    keys('enter'),
  ]);
  woke('Pilot, open Chrome.', [chrome]);
  woke('pilot open chrome', [chrome]);
  woke('Scroll right across space.', [keys('ctrl+right')]);
  woke('Dictate.', [dictate]);
  woke('Rome.', undefined); // Wispr caught only a scrap: nothing runs (Pilot's own words never fill it in)
  test('"Pilots" isn\'t the name', () =>
    expect(brain.wakeCommand('Pilots are great')).toBe('Pilots are great'));
});

describe('training sentences for the speech recognizer: slots filled, no braces left', () => {
  const training = brain.trainingPhrases();
  test.each([
    'open chrome',
    'scroll right across space',
    'click 12',
    'pause video',
    'study mode',
    'switch to College profile',
  ])('has "%s"', (t) => expect(training).toContain(t));
  test('no slot left', () => expect(training.filter((t) => t.includes('{'))).toEqual([]));
});

test('speed: a chain plans in far under 15 ms', () => {
  const t0 = performance.now();
  for (let i = 0; i < 100; i++)
    brain.plan('Pilot, can you open a new Chrome tab, search for Docker networking.', 'Finder');
  expect((performance.now() - t0) / 100).toBeLessThan(15);
});
