# Overriding components

Every page of the admin, and every part of a page, is a [ViewComponent](https://viewcomponent.org): a Ruby class and, for most, an ERB template. The files in `app/views/wibawa` only set the page title and render one component each; the layout is the page shell around them. You can replace any of them with a subclass of your own. This page shows how, and gives one small, working override for each component.

## How an override works

```sh
bin/rails g wibawa:component show_page --no-template
```

```ruby
# app/components/admin/show_page_component.rb (generated)
module Admin
  class ShowPageComponent < Wibawa::ShowPageComponent
  end
end
```

```ruby
# config/initializers/wibawa.rb
config.components[:show_page] = "Admin::ShowPageComponent"
```

From then on Wibawa renders your class wherever it would have rendered its own. `--namespace Backoffice` puts it somewhere other than `Admin`.

There are two ways to change a component. Use the first when it is enough.

**1. Override a method.** With `--no-template` your class has no template of its own, so it keeps using Wibawa's, and you change behaviour by redefining the methods that template calls. `super` gives you Wibawa's answer to adjust. When you upgrade, you get template fixes for free. Every example below is of this kind.

**2. Replace the markup.** Without `--no-template` the generator also copies the template next to your class, and you edit the copy:

```sh
bin/rails g wibawa:component index_table
# app/components/admin/index_table_component.rb
# app/components/admin/index_table_component.html.erb   <- yours now
```

The copy is yours from that moment: later changes to Wibawa's template do not reach it. After an upgrade, compare your copy with the new original (`bundle info wibawa --path` prints where the gem is; the templates are in `app/components/wibawa`). `field` and `combobox` have no template; they build their HTML in Ruby.

### Three things to know

- **Styling.** Wibawa's stylesheet is prebuilt and holds only the classes its own templates use. A Tailwind class you add to a copied template will do nothing unless Wibawa happens to use it too. Put your own CSS in a stylesheet named in `config.stylesheets` and use the [design tokens](tokens.md) there:

  ```css
  /* app/assets/stylesheets/admin.css, loaded by: config.stylesheets = %w[admin] */
  .order-late { background: color-mix(in oklab, var(--wb-danger) 10%, transparent); }
  ```

- **Helpers.** Inside a component, the view is `helpers`: `helpers.link_to`, `helpers.main_app.root_path`, `helpers.wibawa_current_user`. Wibawa's own route helpers (`resources_path`, `resource_path`, `new_resource_path`, `edit_resource_path`), `t`, `icon`, `presenter`, `wibawa_authorized?` and `wibawa_button_class` can be called directly.

- **Stability.** What a component is given when it is built (the keywords listed under "Receives") is the part least likely to change. Method names can still change before 1.0; the `CHANGELOG` will say when one does. An override only decides what is shown. Hiding a button does not forbid the action: that is the job of `config.authorization`.

## The components

Which component draws what:

| Page | Components |
| --- | --- |
| Every page | `sidebar`, `topbar` (phones and tablets), `command_palette` (its record hits are `search_results`), `page_header`, `flash` |
| Index | `index_page`, which renders `scopes`, `filters`, `saved_views`, `index_table`, `pagination` |
| Record | `show_page` |
| New and edit | `form_page`, which renders a `field` per field and `nested_fields` per `has_many` block |
| A long association, in a form or a filter | `combobox`, whose matches are `combobox_options` |
| CSV import | `import_page` and, for a background import, `import_status`; both render `import_result` |
| Dashboard | `dashboard` |
| Report | `report_page`, which renders `pagination` |
| The plain tables: a record's associated records, dashboard tables, a report's rows, the import preview | `table` |
| Custom page (`Wibawa.page`) | `custom_page` |
| Not found, not allowed | `error_page` |

Each example is a complete file. Generate the class with `--no-template`, paste the method in, and add the `config.components` line the generator prints.

### sidebar

The menu on the left: resources by group, then pages and reports, then the user and the theme switch.

Receives: `current_key:` (the open resource's key). Worth overriding: `menu_groups` (the whole menu), `groups` (resources), `extra_groups` (pages and reports), `link_class(active)`, `user_label`.

Example: add links of your own under a "Links" heading.

```ruby
# app/components/admin/sidebar_component.rb
module Admin
  class SidebarComponent < Wibawa::SidebarComponent
    def extra_groups
      super + [ [ "Links", [ Entry.new("Status page", "https://status.example.com", "bolt", false, "Links") ] ] ]
    end
  end
end
```

An entry is label, URL, icon, whether it is the current page, and its group. The command palette builds its own list; see [command_palette](#command_palette) to add the link there too.

### topbar

The bar across the top on phones and tablets, where the sidebar is tucked away: the menu button, the admin's name and the search button.

Receives: nothing. Worth overriding: `title`, `home_url`.

Example: only the first word of a long name, so it fits a phone.

```ruby
# app/components/admin/topbar_component.rb
module Admin
  class TopbarComponent < Wibawa::TopbarComponent
    def title = super.split.first
  end
end
```

Keep `data-wb-sidebar-open` and `data-wb-palette-open` on the buttons if you copy the template: the script opens the menu and the palette from them.

### page_header

The title, breadcrumbs and action buttons at the top of every page.

Receives: `title:`, `breadcrumbs:` (pairs of label and URL), `actions:` (hashes with `label`, `url`, and optionally `icon`, `style`, `method`, `confirm`, `data`), `subtitle:`. Worth overriding: `actions`, `title`, `subtitle`, `action_button(action, menu:)`.

Example: a Help button on every page.

```ruby
# app/components/admin/page_header_component.rb
module Admin
  class PageHeaderComponent < Wibawa::PageHeaderComponent
    def actions
      super + [ { label: "Help", icon: "chat", url: "https://example.com/admin-handbook" } ]
    end
  end
end
```

### index_page

The index page as a whole: header, scopes, the toolbar with search, filters and saved views, the table and the pagination.

Receives: `resource:`, `query:`, `page:`. Worth overriding: `header_actions` (Export, Import, New), `search?`, `filters?`, `saved_views?`, `clear_url`.

Example: on the orders index, a button that opens the matching report.

```ruby
# app/components/admin/index_page_component.rb
module Admin
  class IndexPageComponent < Wibawa::IndexPageComponent
    def header_actions
      return super unless resource.key == "orders"

      [ { label: "By status", icon: "chart", url: helpers.report_path(report: "orders_by_status") } ] + super
    end
  end
end
```

### scopes

The tabs above the table, one per `scope`, each with a count.

Receives: `resource:`, `query:`. Worth overriding: `scopes`, `count_for(scope)`, `url_for_scope(scope)`, `current?(scope)`.

Example: no count on the "All" tab, which on a large table is the one slow query.

```ruby
# app/components/admin/scopes_component.rb
module Admin
  class ScopesComponent < Wibawa::ScopesComponent
    def count_for(scope)
      scope.name.to_s == "all" ? nil : super
    end
  end
end
```

`config.scope_counts = false` turns every count off, and `scope :all, count: false` does it for one scope of one resource; the override is for a rule across resources.

### filters

The Filters popover and the chips that show which filters are on.

Receives: `resource:`, `query:`, `form_id:`, `clear_url:`. Worth overriding: `filters`, `select_options(filter)`, `boolean_options`, `chips`.

Example: list the choices of every select filter alphabetically.

```ruby
# app/components/admin/filters_component.rb
module Admin
  class FiltersComponent < Wibawa::FiltersComponent
    def select_options(filter)
      super.sort_by { |label, _value| label.to_s.downcase }
    end
  end
end
```

### index_table

The table itself: header with sorting, rows, the row actions and the batch bar.

Receives: `resource:`, `records:`, `query:`. Worth overriding: `columns`, `cell(record, column)`, `row_pad`, `numeric?(column)`, `batch_actions`, `show_row_action?(name)`, `empty_message`.

Example: compact rows on every index page.

```ruby
# app/components/admin/index_table_component.rb
module Admin
  class IndexTableComponent < Wibawa::IndexTableComponent
    def row_pad = "h-8 py-0.5"
  end
end
```

For one resource, `index density: :compact` does the same without an override. To colour or mark whole rows you need the template: generate without `--no-template` and edit the `<tr>`.

### pagination

The bar under a table: the "1 to 50 of 240" summary, the page size and the previous and next links. Reports use it too.

Receives: `page:`, `form_id:`. Worth overriding: `render?`, `summary`, `per_page_options`, `page_url(number)`.

Example: no bar when everything fits on one page.

```ruby
# app/components/admin/pagination_component.rb
module Admin
  class PaginationComponent < Wibawa::PaginationComponent
    def render? = page.next? || page.prev?
  end
end
```

That also hides the page-size select on a single page, so someone who chose 500 per page has to change it from a longer list.

### show_page

A record's page: its attributes, panels, associated tables and, when the model uses PaperTrail or Audited, the Change history card.

Receives: `resource:`, `record:`. Worth overriding: `title`, `breadcrumbs`, `header_actions`, `sections`, `value(column)`, `history`.

Example: no Change history card.

```ruby
# app/components/admin/show_page_component.rb
module Admin
  class ShowPageComponent < Wibawa::ShowPageComponent
    def history = nil
  end
end
```

`def history = (super if helpers.wibawa_current_user&.admin?)` shows it to some people only.

### form_page

The new and edit pages: the form, its error summary and the Save and Cancel buttons.

Receives: `resource:`, `record:`. Worth overriding: `title`, `breadcrumbs`, `cancel_url`, `items`, `render_item(form, item, klass)`.

Example: Cancel always goes back to the list, not to the record.

```ruby
# app/components/admin/form_page_component.rb
module Admin
  class FormPageComponent < Wibawa::FormPageComponent
    def cancel_url = resources_path(resource: resource.key)
  end
end
```

### field

One form field: label, input, hint and errors. It has no template.

Receives: `form:`, `field:`, `klass:`, `compact:` (true inside a nested row). Worth overriding: `label_text`, `label_html`, `input_html(type)`, `hint_html`, `error_html`, `select_options`.

Example: take hints from your locale files, so they need not be written into every resource.

```ruby
# app/components/admin/field_component.rb
module Admin
  class FieldComponent < Wibawa::FieldComponent
    def hint_html
      super || helpers.t("admin.hints.#{klass.model_name.i18n_key}.#{name}", default: nil)&.then do |hint|
        content_tag(:p, hint, class: "mt-1.5 text-xs text-ink-2")
      end
    end
  end
end
```

```yaml
# config/locales/admin.en.yml
en:
  admin:
    hints:
      order:
        number: "As printed on the invoice."
```

A `hint:` on the field itself still wins.

### nested_fields

A `has_many` block in a form: its rows, the Add button, Remove, and reordering.

Receives: `form:`, `field:`, `klass:`. Worth overriding: `label`, `add_label`, `children`, `allow_destroy?`, `row(child, index)`.

Example: a shorter Add button.

```ruby
# app/components/admin/nested_fields_component.rb
module Admin
  class NestedFieldsComponent < Wibawa::NestedFieldsComponent
    def add_label = "Add a row"
  end
end
```

Keep the `data-wb-nested-*` attributes if you copy the template: adding, removing and reordering rows in the browser depend on them.

### dashboard

The page at the admin's root: your `Wibawa.dashboard` stats and tables, or without one, a card per resource.

Receives: `dashboard:`. Worth overriding: `resources` (the default dashboard's cards), `stat_value(stat)`, `stat_link(stat)`, `table_records(table)`, `table_columns(table)`.

Example: leave a resource off the default dashboard while keeping it in the menu.

```ruby
# app/components/admin/dashboard_component.rb
module Admin
  class DashboardComponent < Wibawa::DashboardComponent
    def resources = super.reject { |resource| resource.key == "line_items" }
  end
end
```

### report_page

A report: its parameter form, chart and table.

Receives: `report:`, `values:`, `page:`, `chart_rows:`. Worth overriding: `header_actions`, `columns`, `cell(row, column)`, `series`, `chart_value(raw, one)`.

Example: from one report, a button to the records behind it.

```ruby
# app/components/admin/report_page_component.rb
module Admin
  class ReportPageComponent < Wibawa::ReportPageComponent
    def header_actions
      return super unless report.key == "orders_by_status"

      super + [ { label: "All orders", icon: "table", url: resources_path(resource: "orders") } ]
    end
  end
end
```

### command_palette

The <kbd>Cmd</kbd>+<kbd>K</kbd> dialog. It lists pages; record search results are added in the browser.

Receives: nothing. Worth overriding: `items`.

Example: the same extra link as in the sidebar.

```ruby
# app/components/admin/command_palette_component.rb
module Admin
  class CommandPaletteComponent < Wibawa::CommandPaletteComponent
    def items
      super + [ Item.new("Status page", "https://status.example.com", "bolt", "Links") ]
    end
  end
end
```

An item is label, URL, icon and a hint shown beside the label.

### saved_views

The Views popover on the index toolbar (with `config.saved_views` on).

Receives: `resource:`. Worth overriding: `views`, `current`, `own?(view)`, `sharing?`.

Example: list the user's default view first.

```ruby
# app/components/admin/saved_views_component.rb
module Admin
  class SavedViewsComponent < Wibawa::SavedViewsComponent
    def views
      @sorted_views ||= super.sort_by { |view| [ view.default_view && own?(view) ? 0 : 1, view.name.downcase ] }
    end
  end
end
```

Overriding `sharing?` to return false only hides the checkbox; it does not stop a view from being shared.

### table

A plain table of rows, used wherever the admin lists something that is not an index page: the associated records on a record's page, dashboard tables, a report's rows and the import preview. The index table is `index_table`.

Receives: `headings:`, `rows:`, `cells:` (a lambda that turns a row into its cells), and optionally `numeric:` (indexes of right-aligned columns), `caption:`, `style:` (`:inset` inside a card, `:full` as a card of its own) and `align:`. Worth overriding: `head_row_class`, `heading_class(index)`, `row_class`, `cell_class(index)`.

Example: a class of your own on every row, to style from your stylesheet.

```ruby
# app/components/admin/table_component.rb
module Admin
  class TableComponent < Wibawa::TableComponent
    def row_class = class_names(super, "admin-row")
  end
end
```

```css
/* app/assets/stylesheets/admin.css, loaded by: config.stylesheets = %w[admin] */
.admin-row:nth-child(even) { background: var(--wb-surface-2); }
```

### flash

The messages at the top of a page after an action ("Order created.").

Receives: `flash:`. Worth overriding: `messages` (pairs of type and text), `alert?(type)`, `tone_class(type)`.

Example: make a failure unmistakable.

```ruby
# app/components/admin/flash_component.rb
module Admin
  class FlashComponent < Wibawa::FlashComponent
    def messages
      super.map { |type, text| [ type, alert?(type) ? "Not done: #{text}" : text ] }
    end
  end
end
```

### combobox

The search box that replaces a `<select>` when an association has more than 100 records, in forms and in filters. It has no template.

Receives: `name:`, `klass:`, `value:`, `resource_key:`, `id:`, and optionally `form:`, `input_html:`, `multiple:`. Worth overriding: `placeholder`, `call` (all of its HTML).

Example: say what can be typed.

```ruby
# app/components/admin/combobox_component.rb
module Admin
  class ComboboxComponent < Wibawa::ComboboxComponent
    def placeholder = "Type a name or an id…"
  end
end
```

When a list is long enough to need the box, and how it is searched, are not part of the override: `searchable: true` or `false` on a field decides the first, and the target resource's `search` the second. The script that drives the box reads its `data-wb-combobox` attribute and its roles, so keep them if you rewrite `call`.

### combobox_options

The matches listed under a combobox, fetched as you type.

Receives: `options:` (records). Worth overriding: `label(record)`, `empty_text`.

Example: show the id beside the name, for records with the same name.

```ruby
# app/components/admin/combobox_options_component.rb
module Admin
  class ComboboxOptionsComponent < Wibawa::ComboboxOptionsComponent
    def label(record) = "#{super} (##{record.id})"
  end
end
```

The text of the chosen option becomes the text in the box.

### search_results

The record hits in the command palette, fetched as you type.

Receives: `hits:` (each a resource, a record and the path to open). Worth overriding: `label(record)`, `hint(resource)`.

Example: name the list a hit comes from ("Orders") instead of its kind ("Order").

```ruby
# app/components/admin/search_results_component.rb
module Admin
  class SearchResultsComponent < Wibawa::SearchResultsComponent
    def hint(resource) = resource.label
  end
end
```

### import_page

The CSV import page: the upload form, the columns a file may use, and the user's recent background imports.

Receives: `resource:`, `importer:`, `result:` (after an upload), `recent:`. Worth overriding: `title`, `breadcrumbs`, `columns`, `row_limit`, `recent`, `cancel_url`.

Example: list the columns by their labels. A file may use either the attribute name or the label as a heading.

```ruby
# app/components/admin/import_page_component.rb
module Admin
  class ImportPageComponent < Wibawa::ImportPageComponent
    def columns = super.map { |attribute| resource.model.human_attribute_name(attribute) }
  end
end
```

This changes what the page lists, not what an import accepts: that is `import only: [...]` on the resource. The template to download still uses attribute names.

### import_result

What an import did or would do: the errors by line, or after **Check file** the counts and the first rows.

Receives: `resource:`, `result:`. Worth overriding: `errors`, `preview`, `attribute_label(name)`, `change(value)`.

Example: a shorter preview.

```ruby
# app/components/admin/import_result_component.rb
module Admin
  class ImportResultComponent < Wibawa::ImportResultComponent
    def preview = super.first(5)
  end
end
```

### import_status

The page a background import is watched on: waiting, then the result.

Receives: `resource:`, `import:` (a `Wibawa::Import`). Worth overriding: `title`, `label`, `breadcrumbs`, `status_text`.

Example: name an import by its number, not by the uploaded file's name.

```ruby
# app/components/admin/import_status_component.rb
module Admin
  class ImportStatusComponent < Wibawa::ImportStatusComponent
    def label = "Import ##{import.id}"
  end
end
```

While the import waits, the page reloads itself as long as an element with `data-wb-reload` is on it. Keep that attribute if you copy the template. The header's second line still shows the file name; override `title` or the template to change that too.

### custom_page

A `Wibawa.page`: the header with the page's actions, around the content you wrote.

Receives: `page:`, and the page's content as its block. Worth overriding: `title`, `subtitle`, `actions`.

Example: one more line under the title of every custom page.

```ruby
# app/components/admin/custom_page_component.rb
module Admin
  class CustomPageComponent < Wibawa::CustomPageComponent
    def subtitle = [ super, "Staff only." ].compact.join(" ")
  end
end
```

### error_page

What is shown for a page that does not exist (`:not_found`) or that the user may not open (`:forbidden`).

Receives: `status:`. Worth overriding: `code`, `title`, `body`, `back_label`, `back_url`.

Example: one more sentence on the not-found page.

```ruby
# app/components/admin/error_page_component.rb
module Admin
  class ErrorPageComponent < Wibawa::ErrorPageComponent
    def body = status == :not_found ? "#{super} It may have been deleted." : super
  end
end
```

## The layout

One thing is not a component: the layout, `app/views/layouts/wibawa/application.html.erb`. It is the page shell: `<head>`, then the sidebar, top bar, palette and flash components around the page.

Most reasons to touch it have a setting instead: `config.stylesheets` for your CSS, `config.favicon`, `config.brand_color`, `config.font`, `config.site_title`. For anything else, such as a script of your own in `<head>`, copy the file from the gem to the same path in your app. Rails then uses yours:

```sh
mkdir -p app/views/layouts/wibawa
cp "$(bundle info wibawa --path)/app/views/layouts/wibawa/application.html.erb" app/views/layouts/wibawa/
```

Keep what is in its `<head>`: the CSRF and CSP tags, the small script that sets the theme before the page paints, Wibawa's stylesheet and scripts, and `yield :head` (the rich text editor adds its assets there). As with a copied template, the copy is yours: compare it with the original after an upgrade.

## Icons

`icon:` in an action or entry takes one of: `home` `table` `users` `receipt` `box` `cog` `chart` `tag` `store` `card` `chat` `file` `search` `filter` `plus` `download` `x` `chevron-left` `chevron-right` `chevron-up` `chevron-down` `sort` `sun` `moon` `menu` `logout` `pencil` `trash` `grip` `eye` `bolt` `sidebar` `more` `inbox`. An unknown name draws the `table` icon.
