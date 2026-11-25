# Wibawa design spec

**Status: built.** Logo: kawung. Status style: dot plus word. Font: bundled.

Sources: [Impeccable](https://impeccable.style) ("Operate" mode, for product UI), [Taste Skill](https://www.tasteskill.dev) (system and motion rules), and the DESIGN.md format from [xiaopu-ai/web-design](https://github.com/xiaopu-ai/web-design). That last skill is written for landing pages; its scroll effects, WebGL and "three wow moments" rules are deliberately not applied to an admin panel. They will apply to the docs site (roadmap M3).

## 1. Theme and atmosphere

Wibawa means authority and dignity. The interface should feel like a well-run office: calm, exact, nothing shouting. An admin panel is used for hours by staff doing real work, so scanning speed and consistency outrank expression. The brand lives in a few precise details (the indigo rail, the kawung motif, the typeface) and nowhere else.

One line: **quiet panels, aligned figures, color spent on state.**

## 2. Color

The two colors of classical Javanese batik: indigo (*wedel*) for action, soga brown as a faint warmth in the neutrals. Interface stays about 90% neutral.

| Role | Light | Dark | Use |
| --- | --- | --- | --- |
| `--wb-canvas` | `oklch(97.5% 0.004 80)` | `oklch(17% 0.015 265)` | Page ground |
| `--wb-surface` | `oklch(100% 0 0)` | `oklch(21% 0.015 265)` | Cards, tables, inputs |
| `--wb-surface-2` | `oklch(96% 0.005 80)` | `oklch(24% 0.015 265)` | Table header, hover row, toolbar |
| `--wb-line` | `oklch(90% 0.006 80)` | `oklch(30% 0.015 265)` | Borders and dividers |
| `--wb-ink` | `oklch(22% 0.02 265)` | `oklch(95% 0.005 265)` | Primary text, 7:1 or better |
| `--wb-ink-2` | `oklch(47% 0.015 265)` | `oklch(72% 0.01 265)` | Labels, dates, meta, 4.5:1 or better |
| `--wb-primary` | `oklch(42% 0.15 264)` | `oklch(72% 0.11 264)` | Primary button, focus ring, current item |
| `--wb-on-primary` | `#fff` | `oklch(17% 0.015 265)` | Label on a primary button |
| `--wb-rail` | `oklch(27% 0.09 266)` | `oklch(19% 0.05 266)` | Sidebar |
| `--wb-success` / `-warning` / `-danger` / `-info` | hue 155 / 75 / 25 / 240, lightness 45 to 52% | same hues, 76 to 80% | State only: text, dots, rings, 10% tints |

Rules:

- The primary hue moves from 272° to 264°. The current value sits at the edge of violet, and its dark-mode mix came out lavender.
- Accent is for the primary action, the current selection and the focus ring. Record IDs and association links become ink with an underline on hover; today each row has two columns of blue links competing with the one real action.
- Dark mode is designed, not inverted: three explicit surface steps, no translucent white overlays.
- Every color is a CSS variable. `config.brand_color` keeps working and now derives the dark value in OKLCH.

## 3. Typography

- **Family: Plus Jakarta Sans**, one family for everything. It was drawn by Tokotype in Jakarta, which is the reason to keep it rather than switch to a system stack. It will ship inside the gem as WOFF2 (OFL licence), so the admin makes no request to Google Fonts. `config.font_stylesheet` goes away; `config.font = :system` opts out.
- Fixed rem scale, ratio about 1.2: 13 / 14 / 16 / 20 / 24 / 28 px.
- Table and form text 14 px. **Nothing under 13 px**: badges, counters, hints and sidebar group labels are 12 px today.
- Page title 24 px semibold, tracking -0.02em. Section titles 16 px semibold. No all-caps labels, no monospace as decoration.
- Tabular numerals on every number column, date and count.

## 4. Components

Every interactive control gets default, hover, focus-visible, active, disabled and loading states. Today hover and focus exist; active, disabled and loading are missing on most.

- **Buttons.** Two styles only: primary (filled) and secondary (outlined). Ghost stays for icon-only row actions. Exactly one primary per page. Height 36 px desktop, 44 px on touch.
- **Status.** A 6 px dot plus the word, in ink, replaces the filled pill. A full column of red, amber and green pills is the loudest thing on the index page while carrying one word of information. The pill stays available with `as: :badge`.
- **Index table.** Header row on `surface-2`, sticky under the toolbar. Row height 40 px, with a `density: :compact` option at 32 px. Selected rows tint with primary at 6%. Row actions appear on hover and focus on desktop, always on touch.
- **Scopes.** Keep the underline tabs. Counts become plain tabular numbers in `ink-2`, no pill.
- **Filters.** One toolbar: search box, then a Filters button that opens a popover (a bottom sheet on phones). It is a native `<details>`, closed by Escape or a click outside. Active filters show as removable chips above the table, and the button carries their count. There is no side panel; the table gets the full width.
- **Forms.** Input width follows content: numbers and dates 12rem, selects 20rem, text full width (max 40rem). Today a date field stretches 720 px. Errors under the field with `aria-describedby`; first invalid field takes focus. Nested rows keep the current layout.
- **Dashboard.** Stat tiles stay, value at 24 px (never larger than the page title). Tables get a header row.
- **Empty and loading.** Empty states say what the resource is and offer the create action. Turbo navigation shows a 2 px progress bar in primary; no spinners inside content.
- **Searchable select.** A text box with a list under it, used when a `belongs_to` has more than 100 records. Opens on focus, filters as you type, arrow keys and Enter choose, Escape closes. Leaving the box with unmatched text puts the previous choice back; leaving it empty clears the choice. For `has_many` each pick becomes a chip above the box, the list closes after a pick, and Backspace in the empty box removes the last chip.
- **Command palette.** A native `<dialog>` opened by Cmd/Ctrl+K or the sidebar's Search button. Pages filter instantly; record hits arrive after a 200 ms pause. Arrow keys move, Enter opens, Escape closes. This is the one modal in the interface.
- **Sidebar.** Indigo rail stays as the committed shell color. The kawung motif stays in the footer only, at its current strength. The Wibawa mark replaces the initials tile only when `config.logo` is unset and no site title is given.

## 5. Layout

- 4 px base. Scale: 4, 8, 12, 16, 24, 32, 48.
- Content max width 1600 px, 40 px gutters on desktop, 16 px on phones. Sidebar 256 px, collapsible to a 56 px icon rail (new).
- Group by proximity before adding boxes. No card inside a card: the nested-rows block in forms loses its outer card.
- Radii: 6 px controls, 10 px cards. Pills only for the dot-less `as: :badge`.

## 6. Depth

One elevation device per element: a 1 px line **or** a shadow, never both. Cards and tables use the line. Shadows are reserved for things that float (filter sheet, menus, flash).

## 7. Motion

Level L1 of the web-design skill: state feedback only.

- Hover 150 ms, press 90 ms, sheet open 200 ms and close 120 ms, ease `cubic-bezier(.2,.8,.2,1)`. No bounce.
- Animate opacity and transform only.
- Page changes and the theme switch cross-fade in 150 ms (view transitions; browsers without them switch at once).
- Things that appear fade in over 180 ms: the batch bar, flash messages, a new nested row, the filter sheet. They leave at once.
- The button that submitted a form shows a spinner until the server answers. No other spinners.
- No staggered entrances, no scroll effects.
- `prefers-reduced-motion`: color still changes, movement jumps to its end state. Already present; keep.

## 8. Do and don't

Do:

1. Keep one primary button per page.
2. Right-align numbers, left-align words (enums are words).
3. Theme the browser's own surfaces: selection, caret, scrollbars, date pickers.
4. Test every screen at 390 px and 1440 px, in both themes.
5. Keep the built CSS under 60 KB.

Don't:

1. No gradients, glass, glows or gradient text.
2. No colored left-border stripes on cards.
3. No text under 13 px, no tracked capitals.
4. No pulsing dots, sparklines or progress rings as decoration.
5. No modal for something a page or an inline row can do.
6. No hard-coded hex in components; tokens only.
7. No second typeface, no monospace outside code and JSON.
8. No hover effect that moves a neighbouring element.

## 9. Responsive

- Breakpoints: 640 (filter sheet becomes a popover), 1024 (sidebar appears).
- Below 640: page actions collapse to primary plus an overflow menu; tables scroll horizontally inside their card with the first column sticky.
- Touch targets 44 px. No horizontal page scroll at 390 px (now covered by a spec).

## 10. Accessibility

Target: WCAG 2.2 AA. `spec/system/accessibility_spec.rb` runs axe-core on every kind of page in both themes at 1280 and 390 px, and with the filters, batch bar, palette, sidebar rail and form errors showing.

- A "Skip to content" link is the first stop for the Tab key.
- Everything a pointer can do, the keyboard can do. Nested rows reorder by dragging, by the arrow buttons, or by the arrow keys on the handle.
- Closing a popover with Escape puts focus back on its button. The command palette and the searchable select tell assistive technology which option is active.
- Focus is always visible (white on the sidebar) and is not left under a sticky bar.
- Targets are 24 px or larger, 44 px on touch.
- Charts are images with a name; the table under each one carries the same numbers.

## Already fixed

Found while auditing the current UI, and fixed because they were defects rather than taste:

- Dark-mode primary buttons had white text at 2.9:1 contrast. Now dark text, about 6.5:1.
- Dashboard with fewer than four stats showed an empty grey slab; a single table filled half the width.
- The form's sticky footer was transparent on desktop and overlapped the last field.
- Enum columns were right-aligned as if they were numbers.
- Sidebar group labels were below 4.5:1.

## Built last

The six items that were left out of the first build are in:

- **Sticky table header.** The table card is the scroller in both directions and is capped to the window height, so the header row stays in view.
- **`index density: :compact`.** 32 px rows instead of 40.
- **Sidebar rail.** A button in the sidebar footer collapses it to 56 px of icons on desktop; the choice is remembered in the browser. Labels become tooltips.
- **Phones.** With two or more secondary page actions, they fold into a "more" menu next to the primary one. The first table column stays in view while the rest scrolls sideways.
- **Loading and disabled states.** Inputs and selects dim when disabled; a select that submits on change dims until the new page arrives.
- **State colors.** Success, warning, danger and info are tokens (`--wb-success` and so on) at hues 155 / 75 / 25 / 240, with separate light and dark values, each 4.5:1 or better as text.
