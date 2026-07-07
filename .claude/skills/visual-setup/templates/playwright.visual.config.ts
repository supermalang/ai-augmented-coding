import { defineConfig, devices } from '@playwright/test';

/**
 * Visual-baseline Playwright config — full-route screenshots, in-project (no container).
 *
 * Everything lives under `visual-review/` (this file's dir). All paths below are relative to it:
 *   specs/       *.visual.spec.ts        (committed)
 *   baselines/   blessed reference PNGs  (committed — source of truth)
 *   results/     actual/diff/report      (gitignored — regenerable)
 *
 * Determinism:
 *  - toHaveScreenshot appends a per-OS `{platform}` suffix, so `…-linux.png` / `…-darwin.png` /
 *    `…-win32.png` never clash. RULE: bless baselines on the SAME OS your CI runs on (the `CI OS`
 *    field in context.md; a pinned Playwright image documented in docs/visual-testing.md gives
 *    byte-parity). Animations disabled + a small maxDiffPixelRatio absorb sub-pixel noise.
 *  - Do NOT set `channel` — it breaks the `--only-shell` headless build used in CI/Dev Containers.
 *  - `workers` is intentionally unset — Playwright uses the machine's cores; cross-machine scale is
 *    handled by test-level sharding (`--shard`), not by pinning workers here.
 *
 * Approving a change is a HUMAN action: `npx playwright test -c visual-review/playwright.visual.config.ts --update-snapshots`,
 * then commit the changed PNGs. Agents are blocked from --update-snapshots by guard-visual-update.
 */
export default defineConfig({
  testDir: './specs',
  snapshotDir: './baselines',
  outputDir: './results/output',
  fullyParallel: true,                                  // test-level sharding balance
  reporter: process.env.CI ? 'blob' : [['html', { outputFolder: './results/report', open: 'never' }]],
  use: {
    baseURL: process.env.BASE_URL ?? '{{BASE_URL}}',
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },
  expect: { toHaveScreenshot: { maxDiffPixelRatio: 0.01, animations: 'disabled' } },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    command: process.env.SERVE_COMMAND ?? '{{SERVE_COMMAND}}',
    url: process.env.BASE_URL ?? '{{BASE_URL}}',
    reuseExistingServer: !process.env.CI,
  },
});
