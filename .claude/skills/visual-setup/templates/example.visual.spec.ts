import { test, expect } from '@playwright/test';

/**
 * Example full-route visual baseline (Tier 1).
 *
 * Duplicate this per route × viewport you want to guard. The first run in the pinned
 * container writes the baseline PNG (commit it); later runs compare against it and fail
 * on any visual diff, writing baseline/candidate/diff into the HTML report
 * (`npx playwright show-report`).
 *
 * A visual diff is NOT necessarily a bug — for an intended change, a human approves with
 * `--update-snapshots` and commits the new PNG. Agents cannot re-baseline.
 */

test('home route — desktop baseline', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto('/'); // relative to baseURL from the config
  // Stabilise before capture: wait for the app's ready signal instead of a fixed delay.
  await page.waitForLoadState('networkidle');
  await expect(page).toHaveScreenshot('home-desktop.png');
});

test('home route — mobile baseline', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/');
  await page.waitForLoadState('networkidle');
  await expect(page).toHaveScreenshot('home-mobile.png');
});
