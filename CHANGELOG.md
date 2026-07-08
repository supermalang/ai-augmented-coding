# Changelog

All notable changes to this template are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/); versions follow [SemVer](https://semver.org/).

## [1.0.0] — 2026-07-08

First stable release of the AI-augmented coding pipeline template — a Claude Code multi-agent
pipeline that runs a project as a lifecycle (Setup → Definition → Planning → Execution →
Maintenance, with a Governance band), gated by least-privilege agents and shell hooks. Stack-, CI-,
and platform-agnostic; all project specifics are `[CONFIGURE]` keys in `.claude/context.md`.

### Added
- **Lifecycle framing** — `docs/LIFECYCLE.md` (phase view + enforcement gradient) and a
  lifecycle-structured `README`; `docs/TESTING.md` (Testing-Trophy philosophy, a11y-as-assertion,
  critical-journey definition).
- **Code map** — `.claude/code-map.md` generator (`/code-map` skill + agent), a zero-dep router
  index `/planner` and `/locate` read before grepping; `remind-code-map` freshness hook.
- **`/visual-report`** — run the Tier-1 visual suite and serve Playwright's expected/actual/diff
  HTML report; Dev-Container-aware.
- **Bidirectional story-map traceability** — a `Journey:` coordinate on every task; `/story-map`
  reconciles map ↔ roadmap both ways (GAPS + ORPHANS).
- **Dedicated persona docs** — `/discovery` writes full HCD profiles to `docs/personas/`; the
  discovery brief is now a **PRD**.
- **Greenfield stack recommendation** — `/setup` proposes a stack from the PRD's constraints and
  records a stack-choice ADR.
- **Estimates & metrics** — story-point `Estimate` field + DoR; `/retro` trends velocity,
  cycle-time-per-point, carryover, and perf blockers from Delivery blocks.
- **CI-agnostic sharded execution** — portable `test:e2e:ci` / `test:e2e:merge`, a pinned
  Playwright image for byte-identical baselines, and `ci-adapters/` (github / gitlab / container).
- **PR flow** — PRs target `develop` (validated one-by-one, then promoted to `main`); a fixed,
  reviewer-ordered PR template (`docs/pr-template.md` + platform copy) that `/pr-reviewer` fills;
  `docs/branch-protection.md` for the one-time platform setup.
- **Autonomy** — a scoped permissions allow-list + hardened deny in `.claude/settings.json`, and an
  Autonomy block in `.claude/context.md` (auto mode with the hooks as the always-on safety core).

### Changed
- **Visual review is in-project, one folder, no container** — everything under `visual-review/`
  (`specs/`, `baselines/` committed; `results/`, `uat/` gitignored). Determinism via per-OS
  `{platform}` baselines + pixel tolerance; bless on the CI OS / pinned image.
- **`/performance`** — merged `perf-review` + `perf-measure` into one skill with `review` (static)
  and `measure` (dynamic) modes.
- **`/planner`** — validates acceptance-criteria *testability*, the user-value persona, and the
  Journey coordinate before writing a task.

### Removed
- Storybook (Tier 2) and the click-through review-app (Tier 3) from visual review — full-route
  screenshots are the whole surface.
- The separate `perf-review` and `perf-measure` skills/agents (folded into `/performance`).

[1.0.0]: https://github.com/supermalang/ai-augmented-coding/releases/tag/v1.0.0
