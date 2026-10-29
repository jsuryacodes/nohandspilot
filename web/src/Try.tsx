/** /try: the full-screen mock desktop lands here in the next build. */
export function Try() {
  return (
    <main className="grid min-h-dvh place-items-center px-5 text-center">
      <div>
        <img src="/favicon.svg" alt="" width={64} height={64} className="mx-auto size-16" />
        <h1 className="mt-6 font-display text-heading">The live desktop is on its way.</h1>
        <a
          href="/"
          className="mt-4 inline-block text-small text-paper-2 underline underline-offset-4 hover:text-paper"
        >
          Back to the home page
        </a>
      </div>
    </main>
  );
}
