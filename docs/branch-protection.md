# Branch protection — one-time platform setup

The pipeline enforces "no direct pushes; PR + green checks to merge" **locally** via the
`guard-git-flow` hook — but a hook only governs *this* working copy. The durable guarantee is a
**platform setting** on your forge, applied once by a maintainer. It cannot live in the repo, so it
isn't encoded here — this doc is the checklist.

Protect **both** `develop` (the PR target — where `/ship-task` opens every PR) and `main` (production;
promoted from `develop` by a deliberate human step). Names come from `.claude/context.md` →
*Version control & forge* (`PR target branch`, `Protected branches`).

## GitHub — Branch protection rules / Rulesets

Settings → Branches → **Add rule** (or Rules → Rulesets) for `develop` and `main`:

- ✅ Require a pull request before merging (no direct pushes)
- ✅ Require status checks to pass — select the CI check(s), incl. the **visual** check if
  `Visual gate mode = ci` (`.claude/context.md` → *Test execution*)
- ✅ Require branches to be up to date before merging
- ✅ Require conversation resolution
- ✅ Include administrators (so the rule can't be bypassed)
- ✅ Restrict who can push (allow no one to push directly)

## GitLab — Protected branches + merge checks

Settings → Repository → **Protected branches** for `develop` and `main`:

- **Allowed to push:** *No one* · **Allowed to merge:** Maintainers (via MR only)
- Settings → Merge requests: ✅ **Pipelines must succeed** · ✅ **All threads resolved**
- Add the visual job as a required pipeline stage when `Visual gate mode = ci`.

## The promotion step (stays human)

`develop → main` is never automated — open a PR/MR from `develop` to `main`, let the same protection
gate it, and a human merges. `/ship-task` opens PRs onto `develop` and **never merges**; auto-merge or
auto-promotion is out of scope by design.
