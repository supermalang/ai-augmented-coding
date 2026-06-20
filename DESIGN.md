# Design

> **[OPTIONAL — Tier-2 knowledge doc].** The standing design language: the overall *feeling*,
> tone, and UX principles the product should express. This is the qualitative "what should it
> feel like" — the exact tokens, badge classes, icon library, and component rules live in
> `.claude/context.md` (operational, read every run). Per-screen specs live in `docs/design/`.
>
> **Read by:** `/design-import` (reconciles imported designs against this language + keeps the
> index below current), `/ux-review` (judges visual harmony and tone against it). Both treat
> this file as optional — if it's absent they fall back to `.claude/context.md` conventions.

---

## Design principles

- [Principle 1 — e.g. "Clarity over cleverness: every screen has one obvious next action."]
- [Principle 2 — e.g. "Calm by default: muted palette, motion only to confirm or guide."]
- …

## Brand & tone

- **Personality:** [e.g. trustworthy, precise, understated]
- **Voice:** [how copy reads — formal/casual, concise/explanatory]
- **Feeling to evoke:** [e.g. "in control", "effortless", "professional"]

## Visual language (the feel, not the tokens)

- **Mood:** [light/dark, dense/airy, flat/depth]
- **Color intent:** [what the palette signals — e.g. "blue = primary action, never decoration"]
- **Typography intent:** [e.g. "one display weight for headings, one for body; no decorative fonts"]
- **Spacing & density:** [e.g. "generous whitespace; never cram a table"]
- **Motion:** [e.g. "150ms ease; transitions confirm actions, never decorate"]

> Exact values (hex, Tailwind classes, icon library, component library) are defined **once** in
> `.claude/context.md` under *UI conventions* — do not duplicate them here; they would drift.

## Accessibility stance

- [Baseline commitment — e.g. "WCAG 2.1 AA on every shipped screen; color is never the sole signal."]

---

## Screen specs (index)

Each imported or designed screen gets a detailed spec under `docs/design/<slug>.md`, written by
`/design-import`. This table maps the language above to those per-screen specs.

| Screen / feature | Spec | Source |
|---|---|---|
| [Screen name] | [docs/design/&lt;slug&gt;.md](docs/design/) | Stitch / hand / Figma |

> `/design-import` appends a row here each time it writes a new spec.
