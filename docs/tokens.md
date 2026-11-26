# Design tokens

Every colour, both corner radii, the spacing unit and the font of the admin are CSS variables named `--wb-*`. Change one and every component that uses it follows, in light and dark mode.

## Overriding a token

Name a stylesheet of your own in the initializer. It loads after Wibawa's on every admin page:

```ruby
# config/initializers/wibawa.rb
config.stylesheets = %w[admin]   # app/assets/stylesheets/admin.css
```

```css
/* app/assets/stylesheets/admin.css */
:root {
  --wb-radius-control: 0.125rem;        /* squarer buttons and inputs */
  --wb-radius-card: 0.25rem;
  --wb-rail: oklch(25% 0.02 160);       /* a green-black sidebar */
}
.dark {
  --wb-rail: oklch(18% 0.02 160);       /* dark mode has its own value for every colour */
}
```

A colour has two values, one under `:root` and one under `.dark`. If you set only `:root`, dark mode keeps Wibawa's dark value. The other tokens have one value for both.

For the action colour alone you need no stylesheet: `config.brand_color = "#0f766e"` sets `--wb-primary`, and the dark-mode shade is worked out from it.

## The tokens

### Colour

| Token | Light | Dark | Used for |
| --- | --- | --- | --- |
| `--wb-primary` | `oklch(42% 0.15 264)` | derived | Primary button, focus ring, current item. Set it for both modes at once; dark mode relights the same hue |
| `--wb-on-primary` | `#fff` | `oklch(17% 0.015 265)` | Label on a primary button |
| `--wb-canvas` | `oklch(97.5% 0.004 80)` | `oklch(17% 0.015 265)` | Page ground |
| `--wb-surface` | `oklch(100% 0 0)` | `oklch(21% 0.015 265)` | Cards, tables, inputs |
| `--wb-surface-2` | `oklch(96% 0.005 80)` | `oklch(24% 0.015 265)` | Table header, hover row, chips |
| `--wb-line` | `oklch(90% 0.006 80)` | `oklch(30% 0.015 265)` | Borders and dividers |
| `--wb-ink` | `oklch(22% 0.02 265)` | `oklch(95% 0.005 265)` | Primary text |
| `--wb-ink-2` | `oklch(47% 0.015 265)` | `oklch(72% 0.01 265)` | Labels, dates, meta |
| `--wb-ink-3` | `oklch(62% 0.01 265)` | `oklch(55% 0.01 265)` | Icons, placeholders, disabled. Never body text |
| `--wb-rail` | `oklch(27% 0.09 266)` | `oklch(19% 0.05 266)` | Sidebar ground |
| `--wb-on-rail` | `#fff` | same | Text and icons on the sidebar. Quieter items use it at 70% |
| `--wb-scrim` | `oklch(15% 0.01 265 / 0.5)` | same | Behind the phone menu and the command palette |
| `--wb-success` | `oklch(45% 0.12 155)` | `oklch(78% 0.14 155)` | State: text, dots, rings and 10% tints |
| `--wb-warning` | `oklch(52% 0.12 75)` | `oklch(80% 0.13 75)` | State |
| `--wb-danger` | `oklch(50% 0.18 25)` | `oklch(77% 0.13 25)` | State, destructive actions, form errors |
| `--wb-info` | `oklch(48% 0.13 240)` | `oklch(76% 0.11 240)` | State |
| `--wb-series-1` to `--wb-series-6` | `#2a78d6` `#eb6834` `#1baf7a` `#eda100` `#e87ba4` `#008300` | `#3987e5` `#d95926` `#199e70` `#c98500` `#d55181` `#0ca30c` | Chart series, in this order |

If you change a colour, check its contrast yourself. Wibawa's own values meet WCAG AA (4.5:1 for `--wb-ink-2` and the state colours as text on a surface), and its accessibility specs only cover those values. The chart series were chosen so that neighbours stay apart for colour-blind readers; re-check before changing one.

### Shape, space and type

| Token | Value | Used for |
| --- | --- | --- |
| `--wb-radius-control` | `0.375rem` | Buttons, inputs, menu items, chips |
| `--wb-radius-card` | `0.625rem` | Cards, tables, popovers, the command palette |
| `--wb-spacing` | `0.25rem` | The unit every padding, gap and size is a multiple of |
| `--wb-font` | Plus Jakarta Sans, then the system UI font | All text |

`--wb-spacing` scales the whole interface at once: `0.225rem` is about 10% tighter. Only the default is tested; other values can clip text or shrink touch targets, so look at a few pages after changing it. For denser tables alone, use `index density: :compact` on the resource instead.

To use your own font, load it in your stylesheet and set `--wb-font`. `config.font = :system` drops the bundled font file.

## What is promised

From 0.1.0 the tokens in the tables above are public API:

- **A token's name and what it is used for stay.** One is renamed or removed only with a `CHANGELOG` entry, and from 1.0 only in a major version, after a release in which the old name still works.
- **New tokens may be added** in any release.
- **Default values may change** in any release. A new shade of indigo is not a breaking change; if you depend on an exact value, set it yourself.

Not promised:

- `--wb-primary-effective`. It is `--wb-primary` as the current mode shows it. Set `--wb-primary`.
- The `--color-*`, `--radius-*` and `--spacing` variables in the built stylesheet. They belong to the build and point at the tokens above.
- Class names. The stylesheet is prebuilt from the classes Wibawa's own templates use, so a class can disappear when a template stops using it. In an overridden component, style with your own stylesheet and the tokens (see [components.md](components.md)).

## What is not a token

- Font sizes and weights, shadows, and motion timings are fixed.
- Checkboxes keep a small fixed radius, and pills and dots are fully round, whatever the radius tokens say.
- The batik motif behind the sidebar footer is drawn in white inside the stylesheet and does not follow `--wb-on-rail`.
