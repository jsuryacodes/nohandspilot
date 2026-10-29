# No Hands Pilot: design

Everything on the site follows this file. The tokens live in one place in code: the `@theme` block in
[`src/index.css`](src/index.css). Tailwind's own palette, type sizes, radii and shadows are switched
off there, so a class like `text-gray-500` or `rounded-lg` from muscle memory simply won't exist.
Framer Motion takes its timings from [`src/motion.ts`](src/motion.ts), which mirrors the CSS ones.

## Mood

Calm, precise, a little cinematic. A dark room with one warm light: near-black ink, warm paper-white
text, and a single amber signal that only appears when Pilot is doing something. The page should
feel like the product: quiet until you speak, then exact.

Texture: a film grain over the landing page (4.5% in dark, 3% in light) (the `grain` utility) and one soft pool of light at
the top. Never over the mock desktop, which has to read as a real screen.

## Colour

Two colours do most of the work, ink `#08090B` and paper `#F2EDE4`, plus one amber signal. The
tokens are named for their role, so the same class works in both themes: dark is paper-on-ink,
light swaps them to ink-on-paper.

| Token | Dark | Light | Use |
|---|---|---|---|
| `canvas` | `#08090B` | `#F4F0E8` | Page background |
| `surface-1` | `#0E1013` | `#FBF9F5` | Panels, bars, the mock desktop's frame |
| `surface-2` | `#15181C` | `#ECE7DD` | Inputs, hover |
| `surface-3` | `#1E2227` | `#E3DDD1` | Pressed, selected, the chosen theme |
| `raised` | `#23272D` | `#FFFFFF` | Floating things: the HUD, menus |
| `line` / `line-strong` | paper at 9% / 18% | ink at 10% / 20% | Hairlines and card borders / input and button borders |
| `fg` | paper | `#14161A` | Text |
| `fg-2` | paper at 68% | ink at 72% | Secondary text |
| `fg-3` | paper at 52% | ink at 62% | Labels and hints: the faintest text allowed |
| `signal` | `#FFB02E` | `#A85700` | **Pilot is acting.** The waveform while it hears or acts, the active command, the HUD's ✓. Nothing else |
| `signal-soft` | signal at 14% | signal at 12% | A wash behind an acting element, when a line isn't enough |
| `glow` | paper at 7% | white at 75% | The pool of light at the top of the page |

Every text token is at least 4.5:1 on every surface in both themes (`fg-3` is the limit: 4.5 to 5.1).
In light mode the amber is deeper (`#A85700`) so it still reads as text on paper; the bright amber
would be under 2:1 there.

The signal is a cockpit caution amber: warm against the cool ink, and far from Wispr's colours. If
more than one thing on screen is amber and Pilot isn't acting, one of them is wrong. Errors aren't
red: "Didn't catch …" is plain `fg-2` with a `·`, because a miss is information, not an alarm.

### Theme

System, Light or Dark, chosen with three side-by-side buttons in the nav (radio buttons: click one,
or use the arrow keys), never a toggle that cycles. System follows the visitor's OS and changes with
it; Light and Dark are saved in `localStorage` (`src/theme.ts`). A small script in `index.html` sets
`data-theme` before the first paint, so there's no flash of the wrong theme. The app icon doesn't
change: it's a dark tile in both, like an app icon on a Mac.

## Type

| Role | Face | Notes |
|---|---|---|
| Display | **Fraunces** (variable, optical size on auto) | Headlines only. Weight 380, so the high-contrast large optical size shows |
| Body and UI | **Instrument Sans** (variable) | Everything you read that isn't a headline or a command |
| Commands | **JetBrains Mono** (variable) | Anything you'd say to Pilot, plus labels and numbers |
| The mock macOS | System font stack (`font-os`) | So it reads as an OS, not as this website |

All three are self-hosted through `@fontsource-variable` (Latin is about 137 KB for the three). Nothing
loads from a font CDN.

| Token | Size | Line height | Tracking | Use |
|---|---|---|---|---|
| `text-display` | 44 → 100 px (fluid) | 0.98 | −0.022em | The hero headline |
| `text-title` | 34 → 60 px | 1.02 | −0.02em | Section headings |
| `text-heading` | 22 → 30 px | 1.15 | −0.015em | Card and step titles |
| `text-lead` | 20 px | 1.5 | | The line under a headline |
| `text-body` | 17 px | 1.6 | | Paragraphs |
| `text-small` | 15 px | 1.5 | | UI, buttons, the HUD, commands in fields |
| `text-micro` | 12 px | 1.4 | | Mono labels; eyebrows add uppercase and 0.14em tracking |

**Commands always look like something you say:** mono, in straight quotes, starting with "Pilot,"
when shown as speech: `"Pilot, open Chrome"`. Inside a field or a chip, the quotes and "Pilot," can
go, because the field already is the place you say it.

## Space and layout

- 4 px grid (Tailwind's spacing scale). Common steps: 8, 12, 16, 24, 32, 48, 64, 96.
- Content width 1200 px max; side padding 20 px on phones, 32 px from `md`.
- Sections breathe: 96 to 160 px between them on desktop, 64 to 96 px on phones.
- Nothing may scroll sideways at 390, 768, 1024 or 1440 px.

## Radii

| Token | Value | Use |
|---|---|---|
| `rounded-xs` | 6 px | Badges, tags, number badges |
| `rounded-sm` | 8 px | Small controls, focus targets |
| `rounded-md` | 12 px | Buttons, the HUD, chips |
| `rounded-lg` | 16 px | Inputs, the command bar |
| `rounded-xl` | 24 px | Cards, panels, the embedded desktop |

The app icon uses a 14.5/64 corner (about 22.6%), close to macOS's own icon shape.

## Shadows

| Token | Use |
|---|---|
| `shadow-window` | Panels and mock windows: a hairline, a faint top highlight, then a long soft drop |
| `shadow-hud` | The HUD toast and menus |
| `shadow-signal` | An amber halo for the one element Pilot is acting on. Use it for at most one thing at a time |

## Motion

| Name | Time | Use |
|---|---|---|
| fast | 150 ms | Hover, press, focus (the default for `transition`) |
| base | 220 ms | HUD in and out, menus, chips, steps appearing |
| slow | 300 ms | Windows opening, closing and minimising |
| typing | 32 ms a character | Commands typing themselves |
| step | 140 ms apart | The steps of a chain appearing as Pilot does them |

- Easing: `ease-out` `cubic-bezier(0.2, 0.8, 0.2, 1)` for things arriving, `ease-in-out`
  `cubic-bezier(0.65, 0, 0.35, 1)` for things moving in place (the waveform).
- Motion explains cause and effect: a command is said, then the thing it names happens. Nothing
  moves for decoration, and nothing loops except the waveform while Pilot hears.
- `prefers-reduced-motion`: every CSS animation and transition drops to 1 ms, Framer Motion skips
  transforms (`MotionConfig reducedMotion="user"`), and typing appears whole.

## Logo

A raised right hand, palm out, with a sound wave flowing through the palm: Wispr hears, Pilot's
hand acts. It's one file, [`public/favicon.svg`](public/favicon.svg): an ink tile with a paper hand,
the wrist running off the bottom edge, and the amber wave cut through the palm with a mask (a real gap,
not a painted outline). The same file is the favicon (16 px), the dock icon (64 px), the
nav mark and the OG image. At 16 px the fingers merge, but it still reads as a hand with an amber wave.

- Don't recolour it, outline it, or put it on a busy background.
- The wordmark is "No Hands Pilot" in Fraunces at regular weight, set next to the tile.
- The app on the mock desktop's dock is labelled "NoHandsPilot", like a Mac app name.

## The mock Mac (`/try`, and the hero)

It has to read as an operating system, not as this website, so it has its own small set of tokens
(`os-*` in `src/index.css`): neutral, graphite selection like macOS's Graphite accent, in a light and
a dark appearance that follow the site's theme. The site's amber still means one thing in there:
Pilot. It's on the waveform, the HUD's ✓ and the number badges (the real ones are yellow). The only
other colours are the traffic lights and the app tiles in the Dock.

- **Type:** the system font stack (`font-os`) at 13 px for the OS and apps; JetBrains Mono in the
  editor and Terminal.
- **Wallpaper:** drawn in SVG: dunes under a night sky, or in the morning in light mode.
- **Icons:** original tiles with generic glyphs (a folder, a globe, `</>`, a speech bubble, `>_`, a
  note, a gear) and the app's name in the Dock's label. No real app icons or logos. The Pilot
  menu-bar icon is an airplane, like the real app's, drawn from scratch.
- **Windows:** 12 px corners, `shadow-window`, 38 px title bars; open, close and minimise in 300 ms
  (`slow`); minimise drops towards the Dock; full screen keeps the menu bar and hides the Dock.
- **Pages in the mock Chrome** are stand-ins and say so ("Stand-in results. On your Mac, Pilot opens
  the real Google search in Chrome."). Site names appear as plain text, never as their logos.
- **Sizes:** on a laptop `/try` is a real-size Mac (the screen is the viewport, nothing scaled). In
  the hero and on phones it's a 1180 × 720 (or 1024 × 680) Mac scaled to fit, and the command bar
  and HUD sit below it at full size so they stay readable.

## Voice and tone

- **First person, from the maker.** "I built Pilot because …", "my real usage". Not "we", not "users love".
- **Plain and concrete.** Say what it does with a real command. Numbers only from `stats.json` or the
  docs, always with their date range. If a claim can't be sourced, it doesn't go on the page.
- **Honest about the edges.** Wispr does the transcribing; Pilot's own recognizer only hears its
  name. Anything the website can't really do says "On your Mac: …".
- **Product names:** Wispr Flow (text only, never styled like Wispr's brand), Pilot, No Hands Pilot.
- **Words we don't use:** supercharge, seamless, effortless, magic, revolutionary, unleash,
  AI-powered, 10x, "the future of".

## Do / don't

| Do | Don't |
|---|---|
| One amber thing at a time, only while Pilot acts | Amber for links, buttons or decoration |
| Show a real command and its real result | Mock screenshots of things the site can't do |
| Use the real `commands.json` and the real Brain | Copy phrases into the site by hand |
| Draw original, generic app icons with text labels | Use Wispr's, Apple's, Google's or Microsoft's real icons or logos |
| `fg` focus rings (2 px, 3 px offset) on everything focusable | Remove outlines, or rely on colour alone |
| `aria-live` for the HUD only when the visitor caused it | Announce the auto-playing demo to screen readers on a loop |
| Let empty space do the work | Gradient blobs, glass cards for their own sake, emoji feature grids |
