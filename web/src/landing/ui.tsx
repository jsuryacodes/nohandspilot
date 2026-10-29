import type { ReactNode } from 'react';

/** A command as you'd say it: mono, in quotes. */
export const Said = ({ children, className = '' }: { children: string; className?: string }) => (
  <span className={`font-mono text-[0.9em] text-fg ${className}`}>"{children}"</span>
);

export function Section({
  id,
  eyebrow,
  title,
  children,
}: {
  id: string;
  eyebrow: string;
  title: ReactNode;
  children: ReactNode;
}) {
  return (
    <section
      id={id}
      aria-labelledby={`${id}-title`}
      className="mx-auto max-w-[1200px] px-5 py-20 md:px-8 md:py-28"
    >
      <p className="font-mono text-micro uppercase tracking-[0.14em] text-fg-3">{eyebrow}</p>
      <h2
        id={`${id}-title`}
        className="mt-4 max-w-[20ch] font-display text-title font-[380] text-balance"
      >
        {title}
      </h2>
      {children}
    </section>
  );
}

export const Card = ({ children, className = '' }: { children: ReactNode; className?: string }) => (
  <div className={`rounded-xl border border-line bg-surface-1 ${className}`}>{children}</div>
);
