---
name: story-map
description: Story mapping and impact mapping — the product-planning views above the flat backlog. Story map lays the user journey left-to-right (backbone activities → steps) and stories top-to-bottom sliced by release, so you see the walking skeleton and what's in/out of each release. Impact map links a goal to actors → impacts → deliverables, to keep work tied to outcomes. Reads PRODUCT.md, discovery briefs, and the roadmap; writes docs/story-map.md. Read-only on code. Use when the backlog is big enough that a flat list hides the shape of the product.
---

# /story-map — Story Mapping & Impact Mapping

Before starting, read `PRODUCT.md` (vision, personas, goals), the discovery briefs in
`docs/discovery/`, and `docs/ROADMAP.md`. The map is a **view onto** existing stories — it does not
invent new scope.

## Role

The flat roadmap answers "what are the tasks"; it hides "what's the user's journey, and what's the
*smallest end-to-end slice* that delivers value." Story mapping (Jeff Patton) restores that shape:
**activities** across the top (the user's high-level steps in order), **tasks/steps** beneath each, and
**stories** stacked under those, cut by horizontal **release slices** — the top slice being the walking
skeleton. Impact mapping keeps the work honest by tracing every deliverable back to a measurable goal.

## Permissions

✅ CAN read    : `PRODUCT.md`, `docs/discovery/*`, `docs/ROADMAP.md`, `.claude/context.md`
✅ CAN write   : `docs/story-map.md` (story map + optional impact map) · the index row in `PRODUCT.md`
✅ CAN run     : read-only git for context
❌ CANNOT      : create or modify roadmap tasks (that's `/planner`) — it maps what exists, flags gaps
❌ CANNOT      : touch source, tests, or schema

## Argument (optional)

```
/story-map                 # build/refresh the story map from PRODUCT.md + roadmap
/story-map impact          # also (or only) build the impact map
```

---

## Step-by-step

### 1 — Gather the journey and the stories

- From `PRODUCT.md` + discovery briefs: the **personas** and their end-to-end **journey**.
- From `docs/ROADMAP.md`: every task/story, its sprint, priority, and `[x]`/open status.

### 2 — Build the story map

Lay it out as a grid (markdown tables — story maps are 2-D, so prose won't do):

```markdown
## Story map — <product / persona>

**Backbone (user activities, left → right):**
| Discover | Sign up | Configure | Do the core job | Review | Share |

**Steps & stories under each activity, sliced by release:**

### Release 1 — Walking skeleton (smallest end-to-end value)
| Activity | Story (roadmap ID) | Status |
|---|---|---|
| Sign up | 1.1 Email signup | [x] |
| Do the core job | 2.3 Create a record | open |

### Release 2 — …
| … | … | … |
```

Rules:
- The **top slice must be a thin, end-to-end thread** — a user can complete the whole journey, even if
  each step is minimal. Don't fully build one activity before the others exist.
- Map **existing** roadmap IDs into the grid. Where the journey has a step with **no story yet**, mark it
  `⚠️ GAP — no roadmap task` so `/planner` can fill it. Surfacing gaps is the whole point.

### 3 — (Optional) Impact map

```markdown
## Impact map — Goal: <measurable goal, e.g. "cut onboarding time 50%">
- **Actor:** <persona / system>
  - **Impact** (behaviour change we want): <e.g. "completes setup without support">
    - **Deliverable** (what we build): <story / roadmap ID>  ·  or  ⚠️ none yet
```

Read it as "to reach this **goal**, which **actors** must change behaviour (**impact**), and what
minimum **deliverables** cause that?" Deliverables with no goal, and goals with no deliverable, are both
flagged — they're the misalignments.

### 4 — Report back

```
✅ Story map → docs/story-map.md
🗺️  Releases  : <n> slices · <n> stories mapped · <n> journey GAPS (no roadmap task)
🎯 Impact map : <built / skipped>
➡️  Next       : /planner to fill the flagged GAPS
```

---

## What story-map does NOT do

- Does not create or edit roadmap tasks — it maps existing ones and flags gaps for `/planner`.
- Does not invent scope beyond the vision in `PRODUCT.md`.
- Does not touch code, tests, or schema.
- Does not replace the roadmap — it's the journey/outcome view *above* it; the roadmap stays the
  source of truth for task detail and status.
