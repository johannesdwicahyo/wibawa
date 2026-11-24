# Roadmap

Wibawa is pre-release. Each milestone below has an exit test: the milestone is done when every box is ticked, not when a date passes. Items marked *candidate* are ideas to be confirmed by real usage before they are built.

## M0 · Foundations

Make the repository safe to open to contributors.

- [x] Fix the form crash, the mobile table overflow and singular resource labels
- [x] Request specs that boot the engine in a real Rails app (`spec/dummy`)
- [x] Put the project under git and push to GitHub
- [ ] CI matrix: Ruby 3.2–3.4 × Rails 7.2, 8.0, 8.1
- [x] Commit `package-lock.json`, so the "CSS is up to date" check is repeatable
- [ ] RuboCop (rubocop-rails-omakase) in CI
- [ ] Fill in the gemspec (email, homepage) and add CONTRIBUTING, CODE_OF_CONDUCT, SECURITY and issue/PR templates
- [ ] Port the Minitest unit tests to RSpec so there is one test framework

**Exit:** a stranger can clone, run `bundle exec rake` and get green on every matrix cell.

## M1 · 0.1.0, first public release

Something a team can put in front of real staff.

- [ ] Brand: kawung mark chosen and in the README; still to do: final wordmark, colour, favicon, usage guide
- [x] UI redesign to `DESIGN.md`: color tokens, bundled font, 13 px floor, status as dot plus word, sized form fields
- [x] Motion (page cross-fade, save spinner) and a single filter toolbar with chips
- [ ] Rest of `DESIGN.md` (see its "Not built yet" list): sticky header, compact density, collapsible sidebar, phone overflow menu
- [ ] Secure by default: refuse to serve in production until `authenticate_with` is configured (opt out explicitly)
- [ ] System specs for the JavaScript: nested rows (add, remove, reorder), batch selection, filters panel, theme toggle, mobile sidebar
- [ ] Verify what the README promises but nobody has run: Pundit and ActionPolicy adapters, Active Storage attachments, Action Text, Sprockets, the `id` locale, `wibawa:component`
- [ ] Accessibility pass to WCAG 2.2 AA (keyboard, focus order, contrast in both themes)
- [ ] CSV export by primary-key batches instead of OFFSET
- [ ] README with screenshots, and a seeded demo app in the repo
- [ ] Publish to RubyGems with MFA and trusted publishing

**Exit:** the demo app passes the system specs in both themes at 390 px and 1440 px, and `gem install wibawa` works.

## M2 · 0.2, everyday completeness

The things the first users will ask for in week one.

- [ ] MCP server: resources and actions as tools for AI agents, mounted in the engine (official `mcp` gem). Read-only by default; every call goes through the same authorization as the UI
- [ ] Reports: `Wibawa.report` takes a relation or SQL and gives a table, a chart and CSV. Reads from any database Rails is connected to, so a warehouse needs no special code
- [ ] Command palette (Cmd+K) across resources
- [ ] Searchable select for large `belongs_to` collections (today: first 500 records)
- [ ] Custom pages: `Wibawa.page "Reports" do … end` with their own menu entry
- [ ] Filters on `has_many` and through associations
- [ ] Saved views: a named set of filters, scope and sort *(candidate)*
- [ ] Change history hook for audit gems (PaperTrail, Audited) *(candidate)*
- [ ] CSV import *(candidate)*

**Exit:** a mid-sized app (20+ models) can replace ActiveAdmin without writing a custom controller.

## M3 · 0.3, extensibility

Let people change Wibawa without forking it.

- [ ] Documented design tokens: every color, radius and space is a CSS variable with a stability promise
- [ ] Field and column type registry (`Wibawa.field_type :color_swatch, …`)
- [ ] Component override guide with a worked example per component
- [ ] More locales, with a translation completeness check in CI
- [ ] Docs site

**Exit:** two third-party extensions exist that needed no monkey patches.

## M4 · 1.0, stability

- [ ] Freeze the DSL and the component API; semantic versioning from here
- [ ] Upgrade guide from 0.x, deprecation warnings for anything removed
- [ ] Hosted demo
- [ ] Published benchmark against ActiveAdmin and Administrate (index page at 50, 500 rows)

**Exit:** two minor releases in a row with no breaking change reported.
