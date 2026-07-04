import { defineConfig, devices } from '@playwright/test';

/**
 * Visual-baseline Playwright config (Tier 1 — full-route screenshots).
 *
 * Runs IN-PROJECT — no container. Everything lives under `visual-review/`:
 *   visual-review/
 *     playwright.visual.config.ts   ← this file
 *     specs/        *.visual.spec.ts        (committed)
 *     baselines/    blessed reference PNGs  (committed — source of truth)
 *     results/      actual/diff/report      (gitignored — regenerable)
 * All paths below are relative to THIS file, so the whole footprint stays in one folder.
 *
 * Determinism (what replaces the old pinned container):
 *  - Baseline filenames carry the {platform} suffix, so per-OS renders never clash —
 *    Playwright keeps `…-linux.png` / `…-darwin.png` / `…-win32.png` separate.
 *  - RULE: capture and bless baselines on the SAME OS your CI runs on (run the visual
 *    job on a matching runner). That's the local == CI guarantee, minus Docker.
 *  - Animations disabled + a small maxDiffPixelRatio absorb sub-pixel noise.
 *
 * Approving a change is a HUMAN action: `npx playwright test -c visual-review/playwright.visual.config.ts --update-snapshots`,
 * then commit the changed PNGs. Agents are blocked from --update-snapshots by the
 * guard-visual-update hook — they read the approval record, they never re-baseline.
 */
export default defineConfig({
  // Relative to this config's dir (visual-review/) — keeps the whole footprint in one folder.
  testDir: 'specs',
  testMatch: '**/*.visual.spec.ts',

  // BASELINES — the blessed reference PNGs. Source of truth, MUST be committed.
  // The {platform} token keeps local == CI honest (per-OS captures never clash).
  snapshotDir: 'baselines',
  snapshotPathTemplate: '{snapshotDir}/{testFilePath}/{arg}-{platform}{ext}',

  // RUN ARTIFACTS — actual/diff PNGs + traces. Regenerable → gitignored, NEVER committed.
  outputDir: 'results/output',
  reporter: [['html', { outputFolder: 'results/report', open: 'never' }]],

  fullyParallel: true,
  workers: process.env.CI ? 1 : '50%',

  expect: {
    toHaveScreenshot: {
      animations: 'disabled',
      maxDiffPixelRatio: 0.01,
    },
  },

  use: {
    baseURL: process.env.VISUAL_BASE_URL ?? '{{BASE_URL}}',
  },

  // Serve the app (or a static Storybook build at Tier 2) so screenshots have a target.
  // Runs in-project — no container.
  webServer: {
    command: '{{SERVE_COMMAND}}',
    url: process.env.VISUAL_BASE_URL ?? '{{BASE_URL}}',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },

  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
});
