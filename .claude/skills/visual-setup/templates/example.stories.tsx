import type { Meta, StoryObj } from '{{STORYBOOK_RENDERER_PKG}}'; // e.g. @storybook/react

/**
 * Example component + states (Tier 2). Each export is a story = one deterministic
 * visual-test target and one interactive workbench view (`npm run storybook`).
 *
 * Replace this placeholder with a real component. Keep props FIXED (no live data, no
 * timestamps, no random) so the captured pixels are reproducible across runs.
 */
function Button({ label, disabled = false }: { label: string; disabled?: boolean }) {
  return (
    <button disabled={disabled} style={{ padding: '8px 16px', borderRadius: 6 }}>
      {label}
    </button>
  );
}

const meta: Meta<typeof Button> = {
  title: 'Example/Button',
  component: Button,
};
export default meta;

type Story = StoryObj<typeof Button>;

export const Primary: Story = { args: { label: 'Save' } };
export const Disabled: Story = { args: { label: 'Save', disabled: true } };
