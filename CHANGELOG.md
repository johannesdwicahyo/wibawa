# Changelog

## 0.1.0 (unreleased)

First release.

- One-file-per-model resource DSL: menu, scopes, filters, search, index columns, show, form, CSV
- Batch actions (with built-in batch delete) and member actions
- Nested `has_many` forms with add, remove and drag-to-reorder
- Streaming CSV export with formula-injection protection
- Authorization adapters: Pundit, ActionPolicy, or a proc
- Secure by default: outside development and test, every request is refused until `config.authenticate_with` is set
- ViewComponent UI with prebuilt Tailwind CSS, dark mode, English and Indonesian locales
- Design system in `DESIGN.md`: every color is a CSS variable, Plus Jakarta Sans ships in the gem (no third-party requests), statuses show as a dot plus the word
- Sticky table header, `index density: :compact`, a sidebar that collapses to icons, and on phones an overflow menu for page actions with the first column pinned
- State colors (success, warning, danger, info) are CSS variables too
- Accessibility: audited against WCAG 2.2 AA with axe-core; skip link, reordering nested rows without dragging, focus that returns from popovers
- Search and filters share one toolbar: a Filters popover, with active filters as removable chips
- Page changes cross-fade; the button that saved a form shows a spinner
- Searchable select: `belongs_to` fields and filters, and `has_many` fields, turn into a search box once the table passes 100 records
- Audit log of changes made through the admin and the MCP server (`wibawa:audit_log`), with a History button on every record
- Column and menu labels may be procs, resolved when shown
- Saved views: each user can name and reuse an index page's scope, search, filters and sort (`wibawa:saved_views`)
- Command palette (Cmd/Ctrl+K): jump to any page, or search records across resources
- CSV import per resource (`import key: :sku`): all-or-nothing, with a template and line-numbered errors
- Filters on associations: choose a `has_many` record (`filter :tags`) or match an associated column (`filter "line_items.product"`)
- Custom pages: `Wibawa.page` gives a template or block its own menu entry, with action buttons
- Reports: `Wibawa.report` turns SQL or a query block into a paged table, a bar or line chart (up to six series) and a streamed CSV, on any connected database
- MCP server for AI agents (`config.mcp_authenticate_with`): read-only by default, same authorization as the UI, reports included
- Generators: `wibawa:install`, `wibawa:resource`, `wibawa:component`, `wibawa:saved_views`, `wibawa:audit_log`
