import { defineConfig, devices } from '@playwright/test';

/**
 * Visual-baseline Playwright config (Tier 1 — full-route screenshots).
 *
 * Determinism contract:
 *  - Baselines are ONLY valid when captured in the pinned container
 *    (docker-compose.visual.yml). CI MUST use the identical image tag.
 *  - Baseline filenames carry the {platform} suffix so per-OS renders never clash.
 *  - Animations disabled + a small maxDiffPixelRatio absorb sub-pixel noise.
 *
 * Approving a change is a HUMAN action: `npx playwright test -c <this> --update-snapshots`,
 * then commit the changed PNGs. Agents are blocked from --update-snapshots by the
 * guard-visual-update hook — they read the approval record, they never re-baseline.
 */
export default defineConfig({
  testDir: '{{VISUAL_TEST_DIR}}',
  testMatch: '**/*.visual.spec.ts',

  // BASELINES — the blessed reference PNGs. These are the source of truth and MUST be
  // committed. The {platform} token keeps local == CI honest (per-OS captures never clash).
  snapshotPathTemplate: '{testDir}/__screenshots__/{testFilePath}/{arg}-{platform}{ext}',

  // RUN ARTIFACTS — actual/diff PNGs + traces from a run. Regenerable → gitignored,
  // NEVER committed. Pinned explicitly so it always matches .gitignore (test-results/,
  // playwright-report/). Do not point this inside the baselines dir.
  outputDir: 'test-results/visual',

  fullyParallel: true,

  // Explicit worker count — NEVER rely on Playwright's auto-detection inside a
  // container. os.cpus() reports the HOST cores, not the cgroup limit, so autodetect
  // over-subscribes CPU and both slows tests down and makes screenshots flaky.
  // Size PW_WORKERS to the container's allotted vCPU (~1 vCPU + ~1.5 GB RAM each).
  workers: process.env.PW_WORKERS
    ? Number(process.env.PW_WORKERS)
    : (process.env.CI ? 2 : '50%'),

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
