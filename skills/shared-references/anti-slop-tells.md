# Anti-Slop Tells (Shared Reference)

Concrete, verified-duplicate patterns to avoid — shared by
`design-taste-frontend` and `redesign-existing-projects`. Each skill keeps
its own context-specific elaboration (dial-driven overrides, audit-fix
priority, etc.) locally; only the base bans below are shared.

For prose/writing anti-slop guidance (non-UI), see
[`skills/anti-slop-prose/references/vocabulary.md`](../anti-slop-prose/references/vocabulary.md).

## Fake precision

- **Fake-round or fake-precise numbers.** `99.99%`, `50%`, `$100.00` read as invented. Use organic, messy data instead: `47.2%`, `$99.00`, `+1 (312) 847-1928`.
- **Generic person names.** "John Doe", "Jane Smith" — use diverse, realistic-sounding names.
- **Placeholder brand names.** "Acme Corp", "Nexus", "SmartFlow" — invent contextual, believable brand names instead.
- **AI copywriting clichés.** Never use "Elevate", "Seamless", "Unleash", "Next-Gen", "Game-changer", "Delve", "Tapestry", or "In the world of...". Write plain, specific language.

## Color

- **Pure `#000000` background.** Replace with off-black, dark charcoal, or a tinted dark (`#0a0a0a`, `#121212`, or a dark navy).
- **Purple/blue "AI gradient" aesthetic.** The most common AI design fingerprint. Use neutral bases with a single, considered accent instead.
- **More than one accent color, or oversaturated accents.** Pick one accent, keep saturation under 80%.
- **Generic flat `box-shadow`.** Tint shadows to match the background hue rather than using pure black at low opacity.

## Layout

- **Three equal card columns as a feature row.** The most generic AI layout. Use a 2-column zig-zag, asymmetric grid, horizontal scroll, or masonry instead.
- **`height: 100vh` / `h-screen` for full-screen sections.** Use `min-height: 100dvh` (or `min-h-[100dvh]`) to prevent layout jumping on mobile browsers (iOS Safari viewport bug).
- **Complex flexbox percentage math for multi-column layouts.** Use CSS Grid instead.

## Typography

- **Browser default fonts, or Inter as an unconsidered default.** Pick a font with character (e.g. `Geist`, `Outfit`, `Cabinet Grotesk`, `Satoshi`).
