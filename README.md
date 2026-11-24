<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="design/logo/wibawa-symbol-white.svg">
    <img src="design/logo/wibawa-symbol.svg" width="72" height="72" alt="Wibawa logo: the kawung batik motif drawn as four table cells">
  </picture>
</p>

# Wibawa

A modern admin framework for Rails. One small Ruby file per model gives you scopes, filters, search, sortable tables, batch and member actions, nested forms, CSV export and authorization, in the spirit of ActiveAdmin but built on today's Rails:

- **ViewComponent** instead of Arbre. Every page is a component you can subclass and restyle.
- **Turbo**, plus under 200 lines of plain JavaScript. No Stimulus, no jQuery, no build step.
- **Prebuilt Tailwind CSS** ships inside the gem. No Node, no Sass, no asset config in your app.
- **No Formtastic, no Ransack.** Filters and sort columns are an allowlist you declare, so nothing else is queryable.
- Dark mode, mobile layout, English and Indonesian translations.

*Wibawa* (wee-BAH-wah) is Indonesian/Javanese for authority and dignity. The mark is *kawung*, a batik motif once reserved for the Javanese courts.

## Install

```ruby
# Gemfile
gem "wibawa"
```

```sh
bundle install
bin/rails g wibawa:install          # initializer, app/wibawa/, route, one file per model
```

Open `/admin`. Then set up who may enter in `config/initializers/wibawa.rb`:

```ruby
Wibawa.configure do |config|
  config.parent_controller = "ApplicationController"
  config.authenticate_with { redirect_to main_app.root_path unless Current.user&.admin? }
  config.current_user = -> { Current.user }
  config.currency = "IDR"   # as: :money => "Rp 1.250.000"
end
```

Requirements: Ruby 3.2+, Rails 7.2+, turbo-rails, and Propshaft or Sprockets.

## A resource

Each file in `app/wibawa/` registers one resource. Edits reload without a server restart.

```ruby
# app/wibawa/orders.rb
Wibawa.resource Order do
  menu group: "Sales", priority: 1, icon: "receipt"

  scope :all, default: true
  scope :pending, -> { where(status: :pending) }
  scope :paid, -> { where(status: :paid) }

  search :number, "customer.name", "customer.phone"

  filter :status                      # enum => select
  filter :customer                    # belongs_to => select of customers
  filter :total, as: :number_range
  filter :created_at, as: :date_range
  filter :overdue, as: :boolean, apply: ->(value) { value == "true" ? where("due_on < ?", Date.current) : self }

  index sort: { created_at: :desc } do
    id_column
    column :number
    column :customer, sortable: "customers.name"
    column :total, as: :money
    column :status                    # enums and status columns render as colored badges
    column("Items") { |order| order.line_items.size }
    column :created_at, as: :time_ago
    actions
  end

  show do
    attributes :number, :customer, :status
    row :total, as: :money
    panel("Notes") { |order| simple_format(order.notes) }
    table_for :line_items do
      column :product
      column :quantity
      column :price, as: :money
    end
  end

  form do
    section "Order" do
      field :customer
      field :status
      field :notes, hint: "Only staff see this"
    end
    has_many :line_items, sortable: :position do
      field :product
      field :quantity
      field :price
    end
  end

  batch_action :mark_paid, confirm: true do |orders|
    orders.update_all(status: :paid)
    "#{orders.size} orders marked as paid"
  end

  member_action :refund, confirm: "Refund this order?", destructive: true do |order|
    order.refund!
    "Refund started"
  end

  controller do
    def scoped_collection = super.where(store: Current.store)
  end
end
```

Leave any block out and Wibawa infers it from the model: index columns, show rows, form fields (with the right input for enums, associations, dates, booleans, Active Storage and Action Text) and strong params.

### Filtering on associations

```ruby
filter :customer                 # belongs_to: choose a customer
filter :tags                     # has_many / through / habtm: orders that have the chosen tag
filter "line_items.product"      # a column of an associated table: text match
filter "line_items.quantity"     # ... or a number / date range, by the column's type
filter "customer.country", as: :select
```

A filter on an associated column never duplicates rows: an order with three matching line items is listed once. Long lists of choices become a search box, as in forms.

### DSL reference

| Method | What it does |
| --- | --- |
| `menu label:, group:, priority:, icon:, if:` | Sidebar entry. `menu false` hides it. `if:` gets the current user. |
| `scope name, lambda = nil, default:, label:, count:` | Tabs above the table. Without a lambda, calls the model scope of that name. |
| `search *fields` | The search box. Dotted names (`"customer.name"`) search through an association. |
| `filter name, as:, collection:, on:, apply:` | `:string`, `:select`, `:boolean`, `:date_range`, `:number_range`, `:search` (with `on:`). Inferred when omitted. |
| `index per_page:, sort:, count:` | `count: false` skips `COUNT(*)` on huge tables. |
| `column name, as:, label:, sortable:, link:, &block` | Formats: `:money`, `:badge`, `:boolean`, `:date`, `:datetime`, `:time_ago`, `:number`, `:percentage`, `:email`, `:url`, `:image`, `:text`, `:json`, `:tags`. |
| `actions only:, &block` | Row buttons. The block adds your own links. |
| `show { row / attributes / panel / table_for }` | Show page layout. |
| `form { field / fields / section / has_many }` | Form layout. `field name, as:, collection:, hint:, input_html:`. |
| `csv { column ... }` | Export columns (defaults to the index columns). |
| `permit_params *attrs` | Explicit strong params, if you don't want them inferred. |
| `batch_action name, label:, confirm:, &block` | Block gets the selected relation. `batch_action :destroy, false` turns off batch delete. |
| `member_action name, method:, confirm:, destructive:, &block` | Button on the show page. Block gets the record; return a String to flash it. |
| `actions :all, except: [...]` | Turn off CRUD actions for this resource. |
| `includes *associations` | Extra eager loading (column associations are included automatically). |
| `controller { def ... }` | Override `scoped_collection`, `find_record`, `build_record`, `record_params`, `after_save_path`. |

Column, panel and action blocks run in the view or controller, so `link_to`, `number_to_currency`, `redirect_to` and your own helpers all work.

## Dashboard

```ruby
# app/wibawa/dashboard.rb
Wibawa.dashboard do
  stat("Orders today") { Order.where(created_at: Date.current.all_day).count }
  stat("Revenue this month", as: :money, link: -> { resources_path(resource: "orders", scope: "paid") }) do
    Order.paid.where(created_at: Date.current.all_month).sum(:total)
  end

  table "Latest orders", resource: :orders do
    Order.order(created_at: :desc).limit(8)
  end
end
```

Without a dashboard file, the home page lists every resource.

## Authorization

```ruby
config.authorization = :pundit          # or :action_policy
config.authorize_with { |user, action, subject| user.admin? || action.in?(%i[index show]) }
```

Actions checked: `index show new create edit update destroy export`, `batch_<name>` and each member action name. With Pundit or ActionPolicy, a missing policy method falls back sensibly (`batch_*` and member actions to `update?`, `export?` to `index?`), and the index uses your policy scope. Buttons and menu entries you can't use are hidden.

## Large associations

A `belongs_to` field or filter is a plain `<select>` while its table has up to 100 records. Above that it becomes a search box: type to find a record, pick it with the mouse or the arrow keys. A `has_many` field works the same way: a multi-select list up to 100 records, then a search box where each chosen record is a chip you can remove. Nothing to configure, and no record is out of reach because it was not among the first few hundred.

```ruby
field :customer, searchable: true    # always a search box
field :customer, searchable: false   # always a <select> (first 500 records)
```

The search uses the target model's own `search` fields when it is a Wibawa resource, and otherwise its name-like columns (`config.display_name_methods`). Results pass through your authorization scope.

## Audit log

Record every create, update, delete, member action and batch action made through the admin, whether from the browser or by an agent through the MCP server:

```sh
bin/rails g wibawa:audit_log && bin/rails db:migrate
```

```ruby
config.audit_log = true
```

Each entry holds who did it, when, the action, the record, the changed attributes (old and new value) and whether it came from the web or MCP. The log is an ordinary read-only resource called `audit_log`: it appears in the sidebar with search, filters and CSV, every record's page gets a **History** button, and you authorize it like any model (`Wibawa::AuditEntry`). To change its columns, register your own resource with `as: "audit_log"`.

What it does not cover:

- Changes made outside the admin (console, your app's own controllers, background jobs). Use PaperTrail or Audited for a full model history.
- Reads. Agent calls that only read are not logged.
- Changes to nested `has_many` rows are saved but only the parent's own attributes are listed.

Values of attributes matching your app's `filter_parameters`, or that Wibawa already hides from forms (`*_digest`, `*_token`, `encrypted_*`), are stored as `[FILTERED]`. The entry is written right after the change, not in the same transaction.

## Saved views

Let each user save an index page's scope, search, filters, sort and page size under a name, and come back to it from the **Views** button on the toolbar:

```sh
bin/rails g wibawa:saved_views && bin/rails db:migrate
```

```ruby
config.saved_views = true
```

A view belongs to the user who saved it (`config.current_user`). If the admin has no signed-in user, views are shared by everyone. A saved view is only a remembered URL, so it can never show more than the index page itself would.

## Command palette

Press <kbd>Cmd</kbd>+<kbd>K</kbd> (<kbd>Ctrl</kbd>+<kbd>K</kbd> elsewhere) or click Search in the sidebar. The palette lists every page the user may open, a "New ..." shortcut per resource, and every report. From two characters on it also searches records in every resource that declares `search`, five hits each, through the same authorization and `scoped_collection` as the index page. There is nothing to configure.

## CSV import

```ruby
Wibawa.resource Product do
  import                          # every row creates a product
  # import key: :sku              # a row whose sku exists updates that product instead
  # import only: %i[sku name price]
end
```

This adds an **Import CSV** button to the index page, with an upload form and a template to download. The first row names the columns, by attribute name or label; by default they are the form's fields, so a CSV can set nothing the form cannot. For a `belongs_to`, use its id column (`customer_id`).

- **All or nothing.** If any row is invalid, nothing is imported and each problem is listed with its line number.
- **Empty cells leave the value as it is**: a new record keeps its defaults and an existing one keeps its data. An import never clears a field.
- **Authorization.** `:import` on the model (falls back to `create?`), then `create` or `update` on each row.
- The import runs inside the request and is capped at 5,000 rows. With the audit log on, each import is one entry with its counts.

## Custom pages

For anything that is not a model: a settings screen, a maintenance panel, a page of links. It gets a menu entry and the admin layout, and you write no controller or route.

```ruby
# app/wibawa/maintenance.rb
Wibawa.page :maintenance do
  title "Maintenance"
  menu group: "System", icon: "cog"

  view "admin/maintenance"          # app/views/admin/maintenance.html.erb

  action :clear_cache, confirm: "Clear the cache?" do
    Rails.cache.clear
    "Cache cleared"                 # shown as the flash message
  end
end
```

- **Content** is a template from your app (`view`), or a block run in the view: `content { tag.p("Jobs waiting: #{Job.pending.count}") }`.
- **Actions** become buttons in the page header. The block runs in the controller on POST, so it can `redirect_to` or `send_data` itself.
- **Authorization** is `:show` on the `Wibawa::Page` object, and each action's name for its button. Pundit looks for `Wibawa::PagePolicy`.
- Pages appear in the command palette, and their actions in the audit log.

The admin's stylesheet is prebuilt, so a page's template can rely on the design tokens (`var(--wb-surface)`, `var(--wb-line)`, ...) and on classes the admin itself uses, not on arbitrary Tailwind classes. Add your own CSS with `content_for :head`.

## Reports

A report is a read-only page built from a query: a table, an optional chart and CSV export. Put it in `app/wibawa/` next to your resources:

```ruby
Wibawa.report :revenue_by_customer do
  title "Revenue by customer"
  param :from, as: :date, default: -> { 30.days.ago.to_date }
  param :status, as: :select, collection: %w[pending paid]

  sql <<~SQL
    SELECT customers.name AS customer, COUNT(*) AS orders, SUM(orders.total) AS revenue
    FROM orders JOIN customers ON customers.id = orders.customer_id
    WHERE orders.created_at >= :from AND (:status IS NULL OR orders.status = :status)
    GROUP BY customers.name ORDER BY revenue DESC
  SQL

  column :customer
  column :orders
  column :revenue, as: :money
  chart x: :customer, y: :revenue
end
```

- **Params** (`:string`, `:date`, `:number`, `:select`) become a form above the report. Their values are bound to the `:named` placeholders, never interpolated into the SQL.
- **Another database.** `sql "...", on: WarehouseRecord` runs the query on that class's connection, so a data warehouse is just another entry in `database.yml` (any database with an ActiveRecord adapter).
- **No SQL.** Give a block instead: `query { |params| Order.where(created_at: params[:from]..).group(:status).count }`. It may return a relation, a grouped hash or an array of hashes.
- **Charts.** `chart x:, y:` draws bars, for comparing categories. `chart :line, x: :month, y: :revenue` draws a line, for change over time; give it rows in time order. Hover a point for its value.
- **Columns** take the same `as:` formats as index columns. Leave them out to show every column the query returns.
- **Authorization.** Reports are checked as `:show` on the `Wibawa::Report` object: `config.authorize_with { |user, action, subject| ... }` receives it as `subject`, and Pundit looks for `Wibawa::ReportPolicy#show?`.

The page shows the first 1,000 rows and the CSV has all of them. Reports are meant for aggregates; nothing stops a report's SQL from writing, so point reports at a read-only database user where you can.

## MCP server (AI agents)

Wibawa can expose your admin to AI agents over the [Model Context Protocol](https://modelcontextprotocol.io). It is off until you tell it how to recognise a token:

```ruby
# Gemfile
gem "mcp"

# config/initializers/wibawa.rb
config.mcp_authenticate_with do |token|
  ApiToken.find_by(digest: Digest::SHA256.hexdigest(token))&.user&.then { |user| user if user.admin? }
end
config.mcp_write = true   # optional; without it agents can only read
```

The endpoint is `<mount path>/mcp` (for example `/admin/mcp`). Agents send `Authorization: Bearer <token>`.

| Tool | Does | Needs `mcp_write` |
| --- | --- | --- |
| `list_resources` | Resources with their columns, scopes and filters | |
| `list_records` | A page of records; scope, search, filters, sort | |
| `get_record` | One record's detail fields | |
| `create_record`, `update_record`, `delete_record` | Write through the form's strong params | yes |
| `run_action` | Run a `member_action` on a record | yes |

The user your block returns goes through the same `config.authorization`, the same `scoped_collection` overrides and the same strong params as in the browser, and an agent only sees the columns a resource declares. Two things differ from the browser:

- The endpoint does not inherit from `parent_controller` (an agent has no session). In `controller do ... end` blocks, use `wibawa_current_user` rather than your app's `current_user` if the MCP server should honour them.
- Batch actions are not exposed; an agent calls a tool once per record.

**This block is the admin gate for agents.** `authenticate_with` (your browser sign-in check) does not run here, so return a user only if they are allowed into the admin, as the example does with `user.admin?`. If you leave `config.authorization` unset, every user the block returns can read everything, and write everything when `mcp_write` is on.

Store tokens hashed and make them revocable. There is no OAuth flow yet.

## Customizing the UI

- **Colors:** `config.brand_color = "#0f766e"` sets the action color (the dark-mode shade is derived from it). Every color is a CSS variable you can override: `--wb-canvas`, `--wb-surface`, `--wb-line`, `--wb-ink`, `--wb-rail` and so on; see `DESIGN.md`.
- **Fonts:** Plus Jakarta Sans ships inside the gem, so the admin makes no third-party request. `config.font = :system` uses the system UI font.
- **Markup:** copy any component into your app and point Wibawa at it:

  ```sh
  bin/rails g wibawa:component index_table
  ```

  ```ruby
  config.components[:index_table] = "Admin::IndexTableComponent"
  ```

  Components: `sidebar`, `page_header`, `index_page`, `scopes`, `filters`, `index_table`, `pagination`, `show_page`, `form_page`, `field`, `nested_fields`, `dashboard`, `report_page`, `command_palette`, `saved_views`.

## Performance

The index table is one component that loops rows and formats cells with plain methods, so a 500-row page doesn't create thousands of component objects. Associations shown in columns are eager-loaded. Turn off scope counts (`config.scope_counts = false`) and row counts (`index count: false`) on very large tables. CSV export streams in batches of 1,000 instead of loading everything into memory.

## Coming from ActiveAdmin

| ActiveAdmin | Wibawa |
| --- | --- |
| `ActiveAdmin.register Order do` | `Wibawa.resource Order do` |
| `app/admin/orders.rb` | `app/wibawa/orders.rb` |
| `index do ... end`, `column`, `actions` | Same |
| `filter :status, as: :select` | Same, without Ransack predicates |
| `form do \|f\| f.inputs { f.input :x } end` | `form do field :x end` |
| `show do attributes_table do row :x end end` | `show do row :x end` |
| `scope :pending` | Same |
| `batch_action`, `member_action` | Same idea; the block gets the records |
| `permit_params` | Same, but optional |
| `controller do ... end` | Same |

## Development

```sh
bundle install
bundle exec rake             # DSL unit tests, then request specs against the Rails app in spec/dummy
npm install
npm run build:css            # rebuild app/assets/builds/wibawa.css after changing classes
```

Commit the rebuilt CSS; CI fails if it's out of date.

## License

MIT
