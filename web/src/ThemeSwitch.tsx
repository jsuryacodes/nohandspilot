import { useId } from 'react';
import { setTheme, useTheme, type Theme } from './theme';

const icon = {
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.5,
  strokeLinecap: 'round',
  strokeLinejoin: 'round',
} as const;
const OPTIONS: { value: Theme; label: string; path: React.ReactNode }[] = [
  {
    value: 'system',
    label: 'System',
    path: (
      <>
        <rect x="2.5" y="3" width="11" height="8" rx="1.5" />
        <path d="M6 13.5h4" />
      </>
    ),
  },
  {
    value: 'light',
    label: 'Light',
    path: (
      <>
        <circle cx="8" cy="8" r="2.75" />
        <path d="M8 1.75v1.5M8 12.75v1.5M1.75 8h1.5M12.75 8h1.5M3.6 3.6l1 1M11.4 11.4l1 1M3.6 12.4l1-1M11.4 4.6l1-1" />
      </>
    ),
  },
  {
    value: 'dark',
    label: 'Dark',
    path: <path d="M13 9.6A5.25 5.25 0 1 1 6.4 3a4.25 4.25 0 0 0 6.6 6.6Z" />,
  },
];

/** Three choices side by side (radio buttons, so arrow keys work), never a toggle that cycles. */
export function ThemeSwitch({ className = '' }: { className?: string }) {
  const theme = useTheme();
  const name = useId();
  return (
    <fieldset className={`flex rounded-full border border-line p-0.5 ${className}`}>
      <legend className="sr-only">Theme</legend>
      {OPTIONS.map((o) => (
        <label
          key={o.value}
          title={o.label}
          className="grid size-7 cursor-pointer place-items-center rounded-full text-fg-3 transition hover:text-fg has-checked:bg-surface-3 has-checked:text-fg has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-fg"
        >
          <input
            type="radio"
            name={name}
            value={o.value}
            checked={theme === o.value}
            onChange={() => setTheme(o.value)}
            className="sr-only"
          />
          <svg viewBox="0 0 16 16" aria-hidden className="size-4" {...icon}>
            {o.path}
          </svg>
          <span className="sr-only">{o.label}</span>
        </label>
      ))}
    </fieldset>
  );
}
