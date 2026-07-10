---
name: release
description: Release management — runs at the develop → main promotion. Derives the semver bump from conventional commits since the last tag, bumps the version file, updates CHANGELOG.md, drafts release notes, and creates the tag (or proposes it in a release PR). Publishing is a separate, [CONFIGURE], default-off step — with it unset, /release computes the version, writes the changelog/notes, stops at a local tag, and publishes nothing. Never changes the promotion gate; never auto-publishes.
---

# /release — Release management

Before starting, read `.claude/context.md` → *Release* (versioning, version file/command, publish
command) and *Version control & forge*.

Closes the lifecycle: the pipeline ends at merge to `main`; `/release` turns what's on the production
branch into a versioned, changelogged, tagged release. **Publishing is human-gated and off by
default** — releasing is consequential, so it is never automated.

Usage: `/release` (run **after** a human has promoted `develop → main`, on the production branch).

## Permissions

✅ CAN read    : git history/tags · merged PRs · `.claude/context.md`
✅ CAN write   : the version file (per config) · `CHANGELOG.md` · `docs/releases/<version>.md` (draft notes)
✅ CAN run     : read-only git · the version-bump command · `git tag vX.Y.Z` (**local** tag only)
❌ CANNOT      : push the tag or publish to any registry unless `Publish command` is set AND a human confirms
❌ CANNOT      : change the `develop → main` promotion gate · auto-publish on promotion · merge anything

## Preconditions

- You are on the **production branch** (`.claude/context.md` → default `main`), and the human has
  already promoted `develop → main`. `/release` does **not** perform or alter that promotion.
- Commits follow Conventional Commits (enforced by `guard-commit-message`) — that's what the version
  derivation reads.

## Flow

### 1 — Derive the version bump (semver, from conventional commits)

```bash
bash .claude/skills/release/derive-version.sh          # prints "<level> <next-version>"
```

It classifies commits since the last `vX.Y.Z` tag: `fix:`→patch, `feat:`→minor, `<type>!:` or a
`BREAKING CHANGE` body→major (`docs`/`chore`/etc. → no bump). If it prints `none`, there is nothing
release-worthy since the last tag — report that and stop. Respect the `Versioning` config (semver is
the default; don't invent another scheme).

### 2 — Bump the version

Apply the new version using the project's **version file/command** (`.claude/context.md` → *Release*)
— e.g. edit `package.json` / `pyproject.toml` / a `version` file, or run the configured bump command.
Only the configured target; don't guess at others.

### 3 — Update the changelog + draft release notes

- Prepend a `## vX.Y.Z — <YYYY-MM-DD>` section to **`CHANGELOG.md`**, grouping the changes since the
  last tag under **Features** (`feat`), **Fixes** (`fix`), and **Breaking changes** (`!` / `BREAKING
  CHANGE`). Omit empty groups.
- Write the same, fuller, to **`docs/releases/<version>.md`** as the draft release notes (with the
  compare range and contributor/PR references where available).

### 4 — Create the tag (or propose a release PR)

Default: create the annotated tag **locally** and stop —
```bash
git tag -a vX.Y.Z -m "release vX.Y.Z"    # LOCAL only — not pushed
```
If the project prefers review-before-tag, instead open a **release PR** (version bump + changelog +
notes) and let the human merge, then tag. Either way, **nothing is pushed or published** here.

### 5 — Publish — separate, [CONFIGURE], default-off (human-gated)

Read `Publish command` from `.claude/context.md` → *Release*:
- **Unset (default):** STOP. Report the computed version, the local tag, and the notes. Publish
  **nothing** — do not push the tag, do not publish to any registry.
- **Set:** present the version + notes and ask the human to confirm. **Only on explicit confirmation**
  run the publish step (which typically pushes the tag and runs the registry/artifact publish). Never
  auto-run it, and never run it as a side effect of the `develop → main` promotion.

### 6 — Report back

```
🏷️  Version   : vX.Y.Z  (<level> bump from <last-tag>)
📝 Changelog : CHANGELOG.md updated · notes → docs/releases/<version>.md
🔖 Tag       : vX.Y.Z created LOCALLY (not pushed)
🚀 Publish   : <"none configured — nothing published" | "awaiting your confirmation to run <Publish command>">
➡️  Next      : review the notes; push the tag / publish only when you decide to
```

## Fit with the rest of the pipeline

- Runs **after** the human `develop → main` promotion; the promotion gate is unchanged and this never
  triggers a publish from promotion.
- `/report` may surface the latest release (version + date) alongside progress; `/retro` may note what
  shipped in the release. Both are read-only references — neither publishes.

## What /release does NOT do

- Does not auto-publish to any registry, or publish without an explicit human confirmation.
- Does not push the tag by default (local tag only until the gated publish step).
- Does not change or perform the `develop → main` promotion.
- Does not invent a versioning scheme beyond the `[CONFIGURE]` choice (semver default).
