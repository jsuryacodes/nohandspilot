// Command → effect on the mock Mac: the real Brain plans each command, the simulation runs it.
import { describe, expect, test } from 'vitest';
import { brain } from '../brain/site';
import { googleSearch, NEW_TAB, page, youtubeSearch } from './pages';
import { closeTab, frontWindow, initial, press, runStep, tabOf, urlOf, type Desk } from './sim';

/** Says a command the way the command bar does: planned against the front app, run step by step, stopping at an error. */
function say(d: Desk, text: string) {
  const plan = brain.plan(text, d.front, { requireTrigger: false });
  const lines: string[] = [];
  const kinds: string[] = [];
  if (plan.kind === 'run') {
    for (const step of plan.steps) {
      const r = runStep(d, step);
      d = r.desk;
      lines.push(r.line);
      kinds.push(r.kind);
      if (r.kind === 'error') break;
    }
  }
  return { desk: d, lines, kinds, plan };
}
const after = (...texts: string[]) => texts.reduce((d, t) => say(d, t).desk, initial);
const url = (d: Desk) => urlOf(tabOf(d)!);

describe('the first visit: "open Chrome, new tab, search for Docker networking"', () => {
  const r = say(initial, 'open Chrome, new tab, search for Docker networking');
  test('Chrome comes forward with the search in its second tab', () => {
    expect(r.desk.front).toBe('Google Chrome');
    expect(frontWindow(r.desk)).toBe('Google Chrome');
    expect(r.desk.chrome.tabs.map(urlOf)).toEqual([NEW_TAB, googleSearch('Docker networking')]);
    expect(r.desk.chrome.active).toBe(1);
  });
  test("the HUD says each step in Pilot's words", () => {
    expect(r.lines).toEqual(['Opened Google Chrome', 'New tab', 'Searching Docker networking']);
  });
  test('works with "Pilot," in front too', () => {
    expect(say(initial, 'Pilot, open Chrome, new tab, search for Docker networking').desk).toEqual(
      r.desk,
    );
  });
});

describe('apps', () => {
  test('the desktop starts empty, with Finder in front', () => {
    expect(initial.windows).toEqual([]);
    expect(initial.front).toBe('Finder');
  });
  test('open, then switch back to the app before', () => {
    const d = after('open Chrome', 'open VS Code');
    expect(d.front).toBe('Visual Studio Code');
    expect(say(d, 'switch back').desk.front).toBe('Google Chrome');
  });
  test('switch back with nothing before says so', () => {
    expect(say(initial, 'switch back').lines).toEqual(['No previous app yet']);
  });
  test('switching back to Finder opens a Finder window, like a Dock click', () => {
    const d = after('open Chrome', 'switch back');
    expect(d.front).toBe('Finder');
    expect(frontWindow(d)).toBe('Finder');
  });
  test("quit closes the app and forgets its tabs; quitting again says it isn't running", () => {
    const d = after('open Chrome, new tab', 'quit Chrome');
    expect(d.windows).not.toContain('Google Chrome');
    expect(d.chrome.tabs).toEqual([]);
    expect(say(d, 'quit Chrome').lines).toEqual(["Google Chrome isn't running"]);
  });
  test('hide, then open brings it back', () => {
    const d = after('open Claude', 'hide Claude');
    expect(d.hidden).toContain('Claude');
    expect(frontWindow(d)).toBeUndefined();
    expect(frontWindow(say(d, 'open Claude').desk)).toBe('Claude');
  });
  test("an app the mock Mac doesn't have is honest about it", () => {
    const r = say(initial, 'open WhatsApp');
    expect(r.kinds).toEqual(['mac']);
    expect(r.lines).toEqual(['On your Mac: opens WhatsApp']);
  });
  test('a chain stops at the first error', () => {
    const r = say(initial, 'quit Music, open Chrome');
    expect(r.lines).toEqual(["Music isn't running"]);
    expect(r.desk.windows).toEqual([]);
  });
});

describe('Chrome tabs', () => {
  const two = after('open Chrome, new tab, search for Docker networking');
  test('new tab, close tab, reopen tab', () => {
    const three = say(two, 'new tab').desk;
    expect(three.chrome.tabs).toHaveLength(3);
    const closed = say(two, 'close tab').desk;
    expect(closed.chrome.tabs.map(urlOf)).toEqual([NEW_TAB]);
    expect(url(say(closed, 'reopen tab').desk)).toBe(googleSearch('Docker networking'));
  });
  test('next, previous, a numbered tab and the last tab', () => {
    expect(say(two, 'next tab').desk.chrome.active).toBe(0); // wraps
    expect(say(two, 'previous tab').desk.chrome.active).toBe(0);
    expect(say(two, 'go to tab 1').desk.chrome.active).toBe(0);
    expect(say(say(two, 'tab 1').desk, 'switch to the last tab').desk.chrome.active).toBe(1);
  });
  test('closing the last tab closes the window, and Chrome stays open', () => {
    const d = closeTab(after('open Chrome'));
    expect(d.windows).not.toContain('Google Chrome');
    expect(d.running).toContain('Google Chrome');
  });
  test('search from another app opens Chrome and searches in a new tab', () => {
    const d = after('open Terminal', 'search for lofi beats');
    expect(d.front).toBe('Google Chrome');
    expect(url(d)).toBe(googleSearch('lofi beats'));
  });
  test("a site by name opens in a new tab, like Pilot's openURL", () => {
    const d = after('open Chrome', 'open GitHub');
    expect(page(url(d)).kind).toBe('github');
    expect(d.chrome.tabs).toHaveLength(2);
  });
  test('a link, then back and forward', () => {
    const repo = after('open Chrome', 'open GitHub', 'click jsuryacodes/nohandspilot');
    expect(page(url(repo)).kind).toBe('repo');
    const back = say(repo, 'go back').desk;
    expect(page(url(back)).kind).toBe('github');
    expect(page(url(say(back, 'go forward').desk)).kind).toBe('repo');
  });
  test('in VS Code, "search for" is its own project search', () => {
    expect(say(after('open VS Code'), 'search for lofi beats').lines).toEqual([
      'On your Mac: presses ⌘⇧F, types "lofi beats"',
    ]);
  });
});

describe('YouTube: play lofi beats, show numbers, click 3, pause', () => {
  const results = after('play lofi beats on YouTube');
  test('opens the search results', () => expect(url(results)).toBe(youtubeSearch('lofi beats')));
  const shown = say(results, 'show numbers');
  test('numbers everything clickable on the page', () => {
    expect(shown.desk.numbers).toBe(true);
    expect(shown.lines).toEqual(['8 numbers. Say "click" and a number']);
  });
  const clicked = say(shown.desk, 'click 3');
  test('click 3 is the first video: it opens and plays, and the numbers go', () => {
    expect(page(url(clicked.desk)).kind).toBe('watch');
    expect(tabOf(clicked.desk)?.playing).toBe(true);
    expect(clicked.desk.numbers).toBe(false);
    expect(clicked.lines).toEqual(['Clicked 3 "Lofi beats"']);
  });
  test('pause, pause again, play, play again', () => {
    const paused = say(clicked.desk, 'pause the video');
    expect(paused.lines).toEqual(['Paused']);
    expect(tabOf(paused.desk)?.playing).toBe(false);
    expect(say(paused.desk, 'pause').lines).toEqual(['Already paused']);
    const playing = say(paused.desk, 'play');
    expect(playing.lines).toEqual(['Playing']);
    expect(say(playing.desk, 'resume video').lines).toEqual(['Already playing']);
  });
  test("a number that isn't there", () => {
    expect(say(shown.desk, 'click 40').lines).toEqual(['No number 40 on screen']);
  });
  test('pause with no player in front pauses the video playing behind', () => {
    const d = say(clicked.desk, 'open VS Code').desk;
    const r = say(d, 'pause');
    expect(r.lines).toEqual(['Paused']);
    expect(r.desk.chrome.tabs.some((t) => t.playing)).toBe(false);
  });
});

describe('copy link, and edits in a text field (31 Oct)', () => {
  test('copy link by name: the address, never opened', () => {
    const r = say(after('open github'), 'copy link GitHub');
    expect(r.lines).toEqual(['Copied link: https://github.com']);
    expect(r.desk.chrome.tabs.length).toBe(after('open github').chrome.tabs.length);
  });
  test('only links count', () => {
    expect(say(after('open Finder'), 'copy link Downloads').lines).toEqual([
      'Couldn\'t find a link "downloads" on screen',
    ]);
  });
  test("delete, cut and copy a phrase in Claude's message box", () => {
    const typed = after('open Claude', 'new chat', 'type see you soon and good luck');
    const del = say(typed, 'delete good luck');
    expect(del.lines).toEqual(['Deleted "good luck"']);
    expect(del.desk.claude.draft).toBe('see you soon and ');
    expect(say(typed, 'cut see you soon').desk.claude.draft).toBe(' and good luck');
    expect(say(typed, 'copy good luck').desk.claude.draft).toBe('see you soon and good luck');
    expect(say(typed, 'delete hello').lines).toEqual(['No text field here with "hello" in it']);
  });
  test('select X with no text field is a click', () => {
    expect(say(after('open Finder'), 'select Downloads').desk.finder.folder).toBe('Downloads');
  });
  test('keyboard edits say what they would press', () => {
    expect(say(after('open Claude', 'new chat'), 'select last word').lines).toEqual([
      'On your Mac: presses ⌥⇧←',
    ]);
  });
});

describe('click by name', () => {
  test('a Finder sidebar item', () => {
    const r = say(after('open Finder'), 'click Downloads');
    expect(r.desk.finder.folder).toBe('Downloads');
    expect(r.lines).toEqual(['Clicked "Downloads"']);
  });
  test('two things with that name get numbers of their own, then "click 2" picks one', () => {
    const home = after('open Finder', 'click Home');
    const tie = say(home, 'click Downloads');
    expect(tie.lines).toEqual(['2 × "Downloads": say "click 1" or "click 2"']);
    expect(tie.desk.numbers).toEqual(['Finder:side:Downloads', 'Finder:file:Downloads']);
    expect(tie.desk.finder.folder).toBe('Home'); // nothing pressed yet
    const second = say(tie.desk, 'click 2');
    expect(second.lines).toEqual(['Clicked 2 "Downloads"']);
    expect(second.desk.finder.folder).toBe('Downloads');
    expect(second.desk.numbers).toBe(false);
  });
  test('"the first one" / "the last one" while the numbers are up', () => {
    const tie = say(after('open Finder', 'click Home'), 'click Downloads').desk;
    expect(say(tie, 'click the first one').lines).toEqual(['Clicked 1 "Downloads"']);
    expect(say(tie, 'click the last one').lines).toEqual(['Clicked 2 "Downloads"']);
    expect(say(tie, 'click the third one').lines).toEqual(['No number third one on screen']);
  });
  test('nothing by that name', () => {
    expect(say(after('open Finder'), 'click the moon').lines).toEqual([
      'Couldn\'t find "moon" on screen',
    ]);
  });
  test('by mouse, the same effect without the HUD', () => {
    expect(press(after('open Finder'), 'Finder:side:Applications').desk.finder.folder).toBe(
      'Applications',
    );
  });
});

describe('windows', () => {
  test('full screen and back', () => {
    const d = after('open Chrome', 'full screen');
    expect(d.full).toBe('Google Chrome');
    expect(say(d, 'exit full screen').desk.full).toBeUndefined();
  });
  test('minimise, then open brings it back', () => {
    const d = after('open Claude', 'minimise');
    expect(d.minimised).toContain('Claude');
    expect(frontWindow(say(d, 'open Claude').desk)).toBe('Claude');
  });
  test('scroll down, down a lot, to the top and the bottom', () => {
    const d = after('open Chrome, search for docker networking');
    const down = say(d, 'scroll down').desk;
    expect(tabOf(down)?.scroll).toBeGreaterThan(0);
    expect(tabOf(say(down, 'scroll to top').desk)?.scroll).toBe(0);
    expect(tabOf(say(d, 'scroll to bottom').desk)?.scroll).toBe(
      page(googleSearch('docker networking')).length - 1,
    );
  });
  test('nothing to scroll', () => {
    expect(say(initial, 'scroll down').lines).toEqual(['No window to scroll']);
  });
});

describe('per-app commands and macros', () => {
  test('VS Code: toggle terminal', () => {
    const d = after('open VS Code, toggle terminal');
    expect(d.code.terminal).toBe(true);
    expect(say(d, 'hide terminal').desk.code.terminal).toBe(false);
  });
  test('Claude: the sidebar, by naming the app', () => {
    const d = after('open Claude');
    expect(say(d, 'close the Claude sidebar').desk.claude.sidebar).toBe(false);
  });
  test('ask Claude: a new chat with the question sent', () => {
    const d = after('ask Claude what is a docker bridge network');
    expect(d.front).toBe('Claude');
    expect(d.claude.messages).toEqual(['what is a docker bridge network']);
  });
  test('study mode: a new Chrome tab, then a new chat in Claude', () => {
    const r = say(initial, 'study mode');
    expect(r.lines).toEqual(['Opened Google Chrome', 'New tab', 'Opened Claude', 'New chat']);
    expect(r.desk.front).toBe('Claude');
    expect(r.desk.chrome.tabs).toHaveLength(2);
    expect(r.desk.focus).toBe('composer');
  });
  test('coding mode: VS Code with its terminal, then Chrome', () => {
    const d = after('coding mode');
    expect(d.code.terminal).toBe(true);
    expect(d.front).toBe('Google Chrome');
  });
  test('Finder: open downloads from anywhere', () => {
    const r = say(after('open Chrome'), 'open downloads');
    expect(r.desk.front).toBe('Finder');
    expect(r.desk.finder.folder).toBe('Downloads');
    expect(r.lines).toEqual(['Opened Downloads']);
  });
  test('a Settings pane', () => {
    const d = after('open bluetooth settings');
    expect(d.front).toBe('System Settings');
    expect(d.settings.pane).toBe('Bluetooth');
  });
  test('open NoHandsPilot, then what can I say', () => {
    const d = after('open NoHandsPilot');
    expect(frontWindow(d)).toBe('NoHandsPilot');
    const help = say(d, 'what can I say?').desk;
    expect(frontWindow(help)).toBe('Help');
    expect(help.front).toBe('NoHandsPilot');
  });
});

describe('what only a Mac can do says so, with the keys from commands.json', () => {
  test.each([
    ['zoom in', 'On your Mac: presses ⌘='],
    ['lock screen', 'On your Mac: presses ⌃⌘Q'],
    ['scroll right across space', 'On your Mac: presses ⌃→'],
    ['volume up', 'On your Mac: turns the volume up'],
    ['start listening', 'On your Mac: listens for "Pilot" with its offline recognizer'],
    ['search this', "On your Mac: uses the text you've selected"],
    [
      'paste the screenshot',
      'On your Mac: pastes your latest screenshot, then puts back what you copied',
    ],
    [
      'play Florida on Apple Music',
      'On your Mac: plays "Florida" from your Music library, or the first song Apple Music finds',
    ],
    ['switch to college profile', 'On your Mac: opens Chrome in the College profile'],
    ['open file resume', 'On your Mac: finds "resume" with Spotlight and opens it'],
  ])('%s', (text, line) => expect(say(initial, text).lines).toEqual([line]));
  test('the app still comes forward first', () => {
    const r = say(initial, 'open dev tools in Chrome');
    expect(r.desk.front).toBe('Google Chrome');
    expect(r.lines).toEqual(['On your Mac: presses ⌘⌥I']);
  });
  test("a shortcut that isn't set up yet", () => {
    expect(say(after('open Chrome'), 'toggle sidebar').lines[0]).toMatch(/^Not set up yet: /);
  });
  test('"install Pilot" isn\'t a command (follow the Brain)', () => {
    expect(say(initial, 'install Pilot').plan.kind).toBe('unmatched');
  });
});
