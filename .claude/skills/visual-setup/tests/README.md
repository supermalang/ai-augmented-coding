# visual-setup — tests

## Automated (bash)

`verify-prereqs.test.sh` covers the one piece of `/visual-setup` that is a standalone script — the
detect-only prerequisite check. Run it directly:

```bash
bash .claude/skills/visual-setup/tests/verify-prereqs.test.sh
```

It asserts: all-present → exit 0 + "ready"; a missing command → non-zero exit + remediation + the
"no install was attempted" assurance; a known command yields specific remediation; and — statically —
that the script never invokes an installer.

## Manual (agent-driven scaffolding — E2E)

The rest of `/visual-setup` (interview, flag write, Tier 1 scaffold) is agent behaviour against a real
repo, verified by walking these scenarios:

| # | Initial state | Action | Expected |
|---|---|---|---|
| 1 | Fresh project, no flag, prereqs present | `/visual-setup` → choose Tier 1 | `## Visual testing` block written to `.claude/context.md` (`enabled: true`, `tier: 1`, `root: visual-review/`, `CI OS`, paths); `visual-review/playwright.visual.config.ts` + `visual-review/specs/example.visual.spec.ts` + `docs/visual-testing.md` present with `{{…}}` markers substituted; **no** `docker-compose.visual.yml`; example spec runs in-project (`npx playwright test -c visual-review/playwright.visual.config.ts`) and writes a baseline PNG to `visual-review/baselines/` |
| 2 | Node/npx absent | `/visual-setup` | Reports each missing prereq with remediation; **no install attempted**; exits without scaffolding |
| 3 | Already enabled (`enabled: true`) | `/visual-setup` | Detects the existing flag; offers to change tier / re-verify; does **not** duplicate the block or overwrite files silently |
| 4 | Flag absent (Tier 0) | run any pipeline agent | No behaviour change — visual testing is fully inert |

**Determinism check (scenario 1):** the baseline filename carries the `{platform}` per-OS suffix,
the config sets a small `maxDiffPixelRatio`, and the `Visual testing` block records the `CI OS` on
which baselines must be blessed (local == CI without a container).
