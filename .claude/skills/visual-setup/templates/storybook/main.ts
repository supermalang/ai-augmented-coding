import type { StorybookConfig } from '{{STORYBOOK_FRAMEWORK_PKG}}'; // e.g. @storybook/react-vite | @storybook/nextjs | @storybook/vue3-vite

/**
 * Storybook config (Tier 2 — component-isolation visual baselines).
 *
 * The `framework` is stack-specific — /visual-setup detects the UI framework and fills it.
 * If the framework is unsupported, Tier 2 is not scaffolded and the project stays on Tier 1.
 */
const config: StorybookConfig = {
  stories: [
    '../src/**/*.stories.@(ts|tsx|js|jsx)',
    '../{{VISUAL_TEST_DIR}}/**/*.stories.@(ts|tsx|js|jsx)',
  ],
  addons: ['@storybook/addon-essentials'],
  framework: { name: '{{STORYBOOK_FRAMEWORK}}', options: {} }, // detected by /visual-setup
};
export default config;
