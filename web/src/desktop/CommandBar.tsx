import { useEffect, useRef, useState, type RefObject } from 'react';
import { MicGlyph } from './icons';

export type Phase = 'ready' | 'hearing' | 'acting';

/** Five bars that move while Pilot hears and acts on a command: the accent's main job. */
export function Wave({ on }: { on: boolean }) {
  return (
    <span aria-hidden className="flex h-5 w-6 shrink-0 items-center justify-between">
      {[0.55, 0.9, 1, 0.75, 0.45].map((h, i) => (
        <span
          key={i}
          style={{ height: `${h * 100}%`, animationDelay: `${i * -170}ms` }}
          className={`w-[3px] origin-center rounded-full transition-colors ${on ? 'animate-wave bg-signal' : 'scale-y-[0.25] bg-fg-3'}`}
        />
      ))}
    </span>
  );
}

// The Web Speech API, as much of it as the mic button uses (Chrome and Safari prefix it)
interface Recognition {
  lang: string;
  interimResults: boolean;
  onresult:
    | ((e: {
        resultIndex: number;
        results: ArrayLike<ArrayLike<{ transcript: string }> & { isFinal: boolean }>;
      }) => void)
    | null;
  onerror: ((e: { error: string }) => void) | null;
  onend: (() => void) | null;
  start(): void;
  stop(): void;
}
type RecognitionClass = new () => Recognition;
const speech = globalThis as unknown as {
  SpeechRecognition?: RecognitionClass;
  webkitSpeechRecognition?: RecognitionClass;
};
const Recognizer = speech.SpeechRecognition ?? speech.webkitSpeechRecognition;

interface Props {
  value: string;
  onChange: (text: string) => void;
  onRun: (text: string) => void;
  phase: Phase;
  onHearing: (on: boolean) => void;
  chips: { text: string; index: number }[];
  onChip: (index: number) => void;
  input: RefObject<HTMLInputElement | null>;
}

/** Pilot's command bar: type, dictate into it with Wispr Flow (a paste runs by itself, like the real bar), use the
 *  browser's speech recognition, or tap a suggestion. */
export function CommandBar({
  value,
  onChange,
  onRun,
  phase,
  onHearing,
  chips,
  onChip,
  input,
}: Props) {
  const [note, setNote] = useState('');
  const [listening, setListening] = useState(false);
  const paste = useRef<number>(undefined);
  const rec = useRef<Recognition>(undefined);
  useEffect(() => () => window.clearTimeout(paste.current), []);

  const change = (next: string) => {
    window.clearTimeout(paste.current);
    // Typing adds a character at a time; Wispr pastes the whole phrase at once. Run those by themselves (UI.swift).
    if (next.length - value.length >= 4) paste.current = window.setTimeout(() => onRun(next), 400);
    onChange(next);
  };

  const mic = () => {
    if (listening) return rec.current?.stop();
    if (!Recognizer)
      return setNote('This browser has no speech recognition: type, or dictate with Wispr Flow.');
    const r = new Recognizer();
    r.lang = navigator.language || 'en-US';
    r.interimResults = true;
    r.onresult = (e) => {
      const text = Array.from(e.results, (x) => x[0].transcript).join('');
      onChange(text);
      if (e.results[e.results.length - 1].isFinal) onRun(text);
    };
    r.onerror = (e) =>
      setNote(
        e.error === 'not-allowed'
          ? 'The microphone is blocked for this page.'
          : e.error === 'no-speech'
            ? "Didn't hear anything."
            : 'Speech recognition stopped.',
      );
    r.onend = () => {
      setListening(false);
      onHearing(false);
    };
    rec.current = r;
    setNote('');
    setListening(true);
    onHearing(true);
    r.start();
  };

  return (
    <div className="w-full max-w-[640px] space-y-2.5">
      <div role="group" aria-label="Try saying" className="flex flex-wrap justify-center gap-2">
        {chips.map((c, i) => (
          <button
            key={c.index}
            type="button"
            onClick={() => onChip(c.index)}
            className={`rounded-full border px-3 py-1 font-mono text-micro transition hover:bg-surface-2 ${i === 0 ? 'border-line-strong bg-raised text-fg shadow-hud' : 'border-line bg-raised/70 text-fg-2'}`}
          >
            {c.text}
          </button>
        ))}
      </div>
      <form
        onSubmit={(e) => {
          e.preventDefault();
          window.clearTimeout(paste.current);
          onRun(value);
        }}
        className="flex h-[52px] items-center gap-3 rounded-lg border border-line-strong bg-raised px-4 shadow-hud focus-within:border-fg-3"
      >
        <Wave on={phase !== 'ready' || listening} />
        <label className="min-w-0 flex-1">
          <span className="sr-only">Command for Pilot</span>
          <input
            ref={input}
            value={value}
            onChange={(e) => change(e.target.value)}
            onKeyDown={(e) => e.key === 'Escape' && e.currentTarget.blur()}
            placeholder="Say or type a command, e.g. open Chrome, new tab"
            spellCheck={false}
            autoComplete="off"
            enterKeyHint="go"
            className="w-full bg-transparent font-mono text-small text-fg outline-none placeholder:text-fg-3"
          />
        </label>
        <button
          type="button"
          onClick={mic}
          aria-pressed={listening}
          aria-label={listening ? 'Stop listening' : "Speak (your browser's speech recognition)"}
          title={listening ? 'Stop listening' : "Speak (your browser's speech recognition)"}
          className={`grid size-8 shrink-0 place-items-center rounded-full transition ${listening ? 'bg-signal-soft text-signal' : 'text-fg-2 hover:bg-surface-2 hover:text-fg'}`}
        >
          <MicGlyph className="size-4" />
        </button>
        <kbd
          aria-hidden
          className="hidden rounded-xs border border-line px-1.5 font-mono text-micro text-fg-3 sm:block"
        >
          ↩
        </kbd>
      </form>
      <p className="text-center text-micro text-fg-2">
        {note || (
          <>
            Type, use your mic, or hold your Wispr Flow key.{' '}
            <span className="hidden sm:inline">Press / to start typing.</span>
          </>
        )}
      </p>
    </div>
  );
}
