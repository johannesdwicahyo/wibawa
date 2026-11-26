# Changelog

## 0.1.0 (unreleased)

First release.

- One-file-per-model resource DSL: menu, scopes, filters, search, index columns, show, form, CSV
- Batch actions (with built-in batch delete) and member actions
- Nested `has_many` forms with add, remove and drag-to-reorder
- Streaming CSV export with formula-injection protection, in the index page's sort order and without OFFSET
- Authorization adapters: Pundit, ActionPolicy, or a proc
- Secure by default: outside development and test, every request is refused until `config.authenticate_with` is set
- ViewComponent UI with prebuilt Tailwind CSS, dark mode, English and Indonesian locales
- Design system in `DESIGN.md`: every color is a CSS variable, Plus Jakarta Sans ships in the gem (no third-party requests), statuses show as a dot plus the word
- Sticky table header, `index density: :compact`, a sidebar that collapses to icons, and on phones an overflow menu for page actions with the first column pinned
- State colors (success, warning, danger, info) are CSS variables too
- Accessibility: audited against WCAG 2.2 AA with axe-core; skip link, reordering nested rows without dragging, focus that returns from popovers
- A seeded demo app in `demo/` (`bundle exec rake demo`)
- Fixed: a report with SQL containing `%` and no params raised an error
- Fixed, found by running each README promise: Action Text fields crashed the form and showed as the word "description"; attachments crashed the show page; a single image showed as "1 file"; attachments and rich text were missing from inferred forms; `wibawa:component` did not copy the template
- Rich text is shown whole and formatted on a record's page; pages and reports join a resource group of the same name in the sidebar
- The admin has a browser-tab icon (`config.favicon` replaces or removes it)
- Search and filters share one toolbar: a Filters popover, with active filters as removable chips
- Page changes cross-fade; the button that saved a form shows a spinner
- Searchable select: `belongs_to` fields and filters, and `has_many` fields, turn into a search box once the table passes 100 records
- Audit log of changes made through the admin and the MCP server (`wibawa:audit_log`), with a History button on every record
- Column and menu labels may be procs, resolved when shown
- Saved views: each user can name and reuse an index page's scope, search, filters and sort (`wibawa:saved_views`)
- Saved views can be renamed, shared with everyone, and set as the view an index page opens on. The `wibawa_saved_views` table gains `shared` and `default_view` columns
- Columns that look secret are left out by default by their whole name too (`digest`, `token`, `secret`, `salt`, `password`, `api_key`), not only as a suffix; the resource generator says which it left out, and writes `as: :money` for decimal columns named like `total` or `price`
- MCP: `run_batch_action` runs a resource's batch actions on up to 1,000 records; with the audit log on, an agent's reads (`list_records`, `get_record`, `run_report`) are recorded
- A record page lists the model's PaperTrail versions or Audited audits in a Change history card, when the model uses one
- CSV import has a Check file button: a dry run that lists the errors, or what the file would create and change, and keeps nothing
- `config.stylesheets` loads your own stylesheets after Wibawa's on every admin page
- Design tokens are documented with a stability promise (`docs/tokens.md`). New: `--wb-on-rail`, `--wb-scrim`, `--wb-radius-control`, `--wb-radius-card`, `--wb-spacing`, `--wb-font`; no template names a color outside the tokens any more
- Component override guide with a worked example per component (`docs/components.md`); `wibawa:component --no-template` generates a subclass that keeps Wibawa's template
- `Wibawa.column_type` and `Wibawa.field_type` register your own `as:` formats and inputs
- The installer writes `config.current_user = -> { Current.user }` for an app that keeps its user in `Current`, and Wibawa logs a warning when `config.current_user` names a method the controller does not have
- CSV files with more than 5,000 rows (up to 100,000) are imported by a background job, with a page that waits for the result (`wibawa:background_import`)
- Every page is now a component an app can override: new `import_page`, `import_result`, `import_status`, `custom_page`, `error_page`, `flash`, `combobox_options` and `search_results`, and `combobox` can be swapped too
- One `table` component draws every plain table (associated records, dashboard tables, report rows, the import preview), where four copies of the markup did
- The phone top bar is a `topbar` component; the layout file is now only the page shell, and the guide says how to replace it
- A benchmark of the index page against ActiveAdmin and Administrate (`rake benchmark`, results in `docs/benchmark.md`)
- An index row is about 42% less HTML: one short class for what each row repeats, row icons drawn once per page, and one shared form for the row delete buttons
- Authorization now reaches related records: one outside the user's policy scope is shown as `#id`, cannot be newly chosen in a form, import or MCP call, and is not matched by a filter that goes through an association
- `as: :cents` shows money stored as an integer of hundredths
- `config.default_actions` sets which actions a resource has unless it says otherwise, for a read-only panel
- Columns ending in `_hash` or `_key`, and columns the model declares with `encrypts`, are left out by default
- The edit form carries `lock_version`: a save over someone else's change is refused, not silently applied
- Fixed on PostgreSQL: searching a UUID or integer column with a term it cannot hold raised an error
- Fixed: Wibawa's own tables got integer keys in an app whose `ApplicationRecord` assigns UUIDs, so their records collided; the generators now follow the app's key type
- `rake postgres` runs the admin on PostgreSQL with UUID keys, and CI runs it
- Command palette (Cmd/Ctrl+K): jump to any page, or search records across resources
- CSV import per resource (`import key: :sku`): all-or-nothing, with a template and line-numbered errors
- Filters on associations: choose a `has_many` record (`filter :tags`) or match an associated column (`filter "line_items.product"`)
- Custom pages: `Wibawa.page` gives a template or block its own menu entry, with action buttons
- Reports: `Wibawa.report` turns SQL or a query block into a paged table, a bar or line chart (up to six series) and a streamed CSV, on any connected database
- MCP server for AI agents (`config.mcp_authenticate_with`): read-only by default, same authorization as the UI, reports included
- Generators: `wibawa:install`, `wibawa:resource`, `wibawa:component`, `wibawa:saved_views`, `wibawa:audit_log`
