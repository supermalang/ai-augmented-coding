import type { Preview } from '{{STORYBOOK_RENDERER_PKG}}'; // e.g. @storybook/react | @storybook/vue3

/**
 * Global Storybook preview config.
 *
 * Determinism for visual baselines: animations/transitions are killed so screenshots
 * are reproducible. (Playwright also passes `animations: 'disabled'` at capture — this
 * belt-and-braces keeps the interactive workbench and the captured pixels consistent.)
 */
const disableAnimations = () => {
  const id = 'visual-testing-no-animations';
  if (typeof document === 'undefined' || document.getElementById(id)) return;
  const style = document.createElement('style');
  style.id = id;
  style.textContent = `*,*::before,*::after{animation:none!important;transition:none!important;caret-color:transparent!important}`;
  document.head.appendChild(style);
};

const preview: Preview = {
  decorators: [
    (Story) => {
      disableAnimations();
      return Story();
    },
  ],
};
export default preview;
