// The landing page only shows commands Pilot really runs (and teaching it, which plans as "teach").
import { describe, expect, test } from 'vitest';
import { brain, makeBrain } from '../brain/site';
import { BEFORE_AFTER, CHAIN, HERO_SHOW, TAUGHT, TEACH, TEACH_THAT } from './said';

describe('every command on the landing page runs', () => {
  test.each([...BEFORE_AFTER.map((r) => r.said), CHAIN, ...HERO_SHOW])('%s', (said) => {
    expect(brain.plan(said, 'Google Chrome', { requireTrigger: false }).kind).toBe('run');
  });
  test('teaching parses as teaching, and the taught phrase then runs', () => {
    expect(brain.plan(TEACH)).toEqual({
      kind: 'teach',
      phrase: 'focus time',
      commands: ['open Notion', 'mute'],
    });
    expect(brain.plan(TEACH_THAT)).toEqual({ kind: 'teach', commands: ['new tab'] });
    expect(makeBrain({ 'focus time': ['open notion', 'mute'] }).plan(TAUGHT).kind).toBe('run');
  });
});
