import { test, expect } from '@playwright/test';

/**
 * Component-isolation visual baselines (Tier 2).
 *
 * Screenshots a STATIC Storybook build (`visual-review/storybook/static`, produced by
 * `storybook build -o visual-review/storybook/static`) served by the visual config's webServer —
 * no live dev server needed in CI. Same in-project rules as Tier 1, so the {platform} per-OS
 * suffix and pixel tolerance carry over unchanged.
 *
 * Story id = "<title-kebab>--<export-name>", e.g. title 'Example/Button' + export
 * `Primary` → 'example-button--primary'. A component diff points at the exact story.
 */
const stories = [
  { id: 'example-button--primary', name: 'button-primary' },
  { id: 'example-button--disabled', name: 'button-disabled' },
];

for (const s of stories) {
  test(`story: ${s.id}`, async ({ page }) => {
    await page.goto(`/iframe.html?id=${s.id}&viewMode=story`);
    await page.waitForLoadState('networkidle');
    await expect(page).toHaveScreenshot(`${s.name}.png`);
  });
}
