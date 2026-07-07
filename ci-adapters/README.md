# CI adapters — thin, per-vendor, pick one

The test-execution **core is CI-agnostic**: `npm run test:e2e:ci` shards via
`--shard=${SHARD_INDEX:-1}/${SHARD_TOTAL:-1}` and defaults to `1/1` (the whole suite, no CI). Each
shard emits a **blob** report; `npm run test:e2e:merge` stitches one HTML report.

An adapter's *only* job is to map the vendor's parallelism variables onto `SHARD_INDEX` /
`SHARD_TOTAL`, run on the **pinned Playwright image** (byte-identical screenshots — see
`docs/visual-testing.md` and the `Playwright image` key in `.claude/context.md`), and merge the blob
reports. **Keep the one adapter that matches `CI provider` in `.claude/context.md`; delete the rest.**

| Adapter | Vendor parallelism → shard vars |
|---|---|
| `github/` | `strategy.matrix` → `SHARD_INDEX` / `SHARD_TOTAL`; build once + share artifact; cache browsers; a `merge-reports` job |
| `gitlab/` | native `parallel: N` → `CI_NODE_INDEX` / `CI_NODE_TOTAL`; `image:` = the pinned Playwright image |
| `container/` | a shell loop / `docker run -e SHARD_INDEX=… -e SHARD_TOTAL=…` on the pinned image |

Nothing here is referenced by the pipeline core; these are copy-and-adjust starting points, kept out
of the portable path on purpose (no CI vendor is named in the core).
