# Changelog

## 0.1.0 (unreleased)

First release.

- One-file-per-model resource DSL: menu, scopes, filters, search, index columns, show, form, CSV
- Batch actions (with built-in batch delete) and member actions
- Nested `has_many` forms with add, remove and drag-to-reorder
- Streaming CSV export with formula-injection protection
- Authorization adapters: Pundit, ActionPolicy, or a proc
- ViewComponent UI with prebuilt Tailwind CSS, dark mode, English and Indonesian locales
- Design system in `DESIGN.md`: every color is a CSS variable, Plus Jakarta Sans ships in the gem (no third-party requests), statuses show as a dot plus the word
- Search and filters share one toolbar: a Filters popover, with active filters as removable chips
- Page changes cross-fade; the button that saved a form shows a spinner
- Reports: `Wibawa.report` turns SQL or a query block into a table, a bar chart and CSV, on any connected database
- MCP server for AI agents (`config.mcp_authenticate_with`): read-only by default, same authorization as the UI
- Generators: `wibawa:install`, `wibawa:resource`, `wibawa:component`
