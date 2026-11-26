require "spec_helper"
require "tmpdir"
require "generators/wibawa/component/component_generator"

# docs/tokens.md and docs/components.md make promises. These keep them true.
RSpec.describe "Wibawa docs", type: :request do
  describe "docs/tokens.md" do
    let(:css) { File.read("src/wibawa.css") }
    let(:doc) { File.read("docs/tokens.md") }
    let(:declared) { css.scan(/^\s*(--wb-[\w-]+):/).flatten.uniq }

    it "lists every token the stylesheet declares, and no other" do
      series = (1..6).map { |n| "--wb-series-#{n}" } # written as a range in the table
      documented = doc.scan(/`(--wb-[\w-]+)`/).flatten.uniq - %w[--wb-series-1 --wb-series-6] + series
      expect(documented.sort).to eq(declared.sort)
    end

    it "gives the values the stylesheet has" do
      light = css[/^:root \{.*?^\}/m]
      dark = css[/^\.dark \{.*?^\}/m]
      value = ->(block, token) { block[/^\s*#{Regexp.escape(token)}:\s*([^;]+);/, 1] }
      rows = doc.scan(/^\| `(--wb-[\w-]+)` \| `([^`]+)` \| (?:`([^`]+)`|(\w+)) \|/)
      expect(rows.size).to be >= 15
      rows.each do |token, documented_light, documented_dark, word|
        expect([ token, value.(light, token) ]).to eq([ token, documented_light ])
        expect([ token, value.(dark, token) ]).to eq([ token, documented_dark ]) if documented_dark
        expect([ token, value.(dark, token) || value.(light, token) ]).to eq([ token, documented_light ]) if word == "same"
      end
    end

    it "is right that no template names a colour outside the tokens" do
      palette = /\b(?:text|bg|ring|border|fill|stroke|outline|divide|accent|decoration|shadow|from|to)-(?:white|black|(?:slate|gray|zinc|neutral|stone|red|orange|amber|yellow|green|emerald|teal|blue|indigo|violet|rose)-\d+|\[#\h+\])/
      found = Dir["app/**/*.{rb,erb}", "app/assets/javascripts/*.js"].flat_map { |file| File.read(file).scan(palette).map { |name| "#{file}: #{name}" } }
      expect(found).to eq([])
    end

    it "loads the app's stylesheets after Wibawa's" do
      get "/admin"
      expect(response.body.scan(/<link rel="stylesheet"/).size).to eq(1)
      Wibawa.config.stylesheets = %w[wibawa] # the one stylesheet the test app can resolve, a second time
      get "/admin"
      expect(response.body.scan(/<link rel="stylesheet"/).size).to eq(2)
    ensure
      Wibawa.config.stylesheets = []
    end
  end

  describe "docs/components.md" do
    let(:doc) { File.read("docs/components.md") }
    let(:keys) { Dir["app/components/wibawa/*_component.rb"].map { |file| File.basename(file, "_component.rb") } - %w[base] }
    # Each example is a complete file that starts with its path.
    let(:examples) { doc.scan(/```ruby\n# app\/components\/admin\/(\w+)_component\.rb\n(.*?)```/m).to_h }

    let!(:customer) { Customer.create!(name: "Sari") }
    let!(:order) { Order.create!(number: "A-1", customer: customer) }

    after do
      Wibawa.config.components.clear
      Wibawa.config.saved_views = false
      Wibawa.config.background_import = false
      Object.send(:remove_const, :Admin) if defined?(Admin)
    end

    it "has a section and a worked example for every component, and the README lists them all" do
      expect(doc.scan(/^### (\w+)$/).flatten - %w[Three]).to match_array(keys)
      expect(examples.keys - %w[show_page]).to match_array(keys - %w[show_page]) # show_page's first block is the generated stub
      expect(File.read("README.md")[/^  Components: (.*)$/, 1].scan(/`(\w+)`/).flatten).to match_array(keys)
    end

    it "generates a class with no template on --no-template" do
      Dir.mktmpdir do |dir|
        Wibawa::Generators::ComponentGenerator.start(%w[show_page --no-template --quiet], destination_root: dir)
        expect(Dir.children(File.join(dir, "app/components/admin"))).to eq(%w[show_page_component.rb])
      end
    end

    it "gives examples that do what they say" do
      before = {}
      get "/admin"
      before[:dashboard_links] = response.body.scan('href="/admin/line_items"').size
      get "/admin/orders"
      expect(response.body).to match(/Pending<\/option>.*Paid<\/option>/m)
      expect(response.body).to include('aria-label="Pagination"')
      get "/admin/customers/#{customer.id}"
      expect(response.body).to include("data-wb-history")

      # The code comes from this repository's own docs page, nowhere else: running it is the point of the spec.
      doc.scan(/```ruby\n(# app\/components\/admin\/\w+_component\.rb\n.*?)```/m).flatten.each { |code| eval(code, TOPLEVEL_BINDING) } # rubocop:disable Security/Eval
      keys.each { |key| Wibawa.config.components[key.to_sym] = "Admin::#{key.camelize}Component" }
      Wibawa.config.saved_views = true
      Wibawa::SavedView.create!(resource_key: "orders", name: "Alpha", query: "search=a")
      Wibawa::SavedView.create!(resource_key: "orders", name: "Zulu", query: "search=z", default_view: true)
      I18n.backend.store_translations(:en, admin: { hints: { order: { number: "As printed on the invoice." } } })

      get "/admin"
      expect(response.body).to include("Status page", 'href="https://status.example.com"')                 # sidebar, command_palette
      expect(response.body.scan("https://status.example.com").size).to eq(2)
      expect(response.body.scan('href="/admin/line_items"').size).to eq(before[:dashboard_links] - 1)       # dashboard
      expect(response.body).to include("https://example.com/admin-handbook")                               # page_header

      get "/admin/orders?search=A"
      body = response.body
      expect(body).to include('href="/admin/reports/orders_by_status"', "By status")                       # index_page
      expect(body[/<nav[^>]*aria-label="Scopes".*?<\/nav>/m].scan("tabular-nums").size).to eq(1)           # scopes: Pending has a count, All has none
      expect(body).to match(/Paid<\/option>.*Pending<\/option>/m)                                          # filters
      expect(body).to include("h-8 py-0.5")                                                                # index_table
      expect(body).not_to include('aria-label="Pagination"')                                               # pagination
      expect(body.index(">Zulu<")).to be < body.index(">Alpha<")                                           # saved_views

      get "/admin/customers/#{customer.id}"
      expect(response.body).not_to include("data-wb-history")                                              # show_page

      get "/admin/orders/#{order.id}/edit"
      expect(response.body).to include("As printed on the invoice.", "Add a row")                          # field, nested_fields
      expect(response.body).to match(%r{href="/admin/orders"[^>]*>\s*Cancel})                              # form_page

      get "/admin/reports/orders_by_status"
      expect(response.body).to include("All orders")                                                       # report_page

      post "/admin/orders/batch", params: { batch_action: "destroy" }
      follow_redirect! # to the index,
      follow_redirect! # which opens on the default saved view made above
      expect(response.body).to include("Not done: ")                                                       # flash

      stub_const("Wibawa::ComboboxComponent::THRESHOLD", 0)
      get "/admin/orders/#{order.id}/edit"
      expect(response.body).to include('placeholder="Type a name or an id…"')                              # combobox
      get "/admin/orders/options/Customer", params: { q: "Sari" }
      expect(response.body).to include("Sari (##{customer.id})")                                            # combobox_options
      get "/admin/-/search", params: { q: "A-1" }
      expect(response.body).to include(">Orders</span>")                                                   # search_results

      get "/admin/orders/import"
      expect(response.body).to include(">Customer</li>")                                                   # import_page
      expect(response.body).not_to include(">customer_id</li>")
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "o.csv"), "number,customer_id\n" + (1..6).map { |n| "N-#{n},#{customer.id}\n" }.join)
        post "/admin/orders/import", params: { file: Rack::Test::UploadedFile.new(File.join(dir, "o.csv"), "text/csv"), dry_run: "1" }
      end
      expect(response.body).to include("would create 6", "The first 5 rows")                               # import_result

      Wibawa.config.background_import = true
      import = Wibawa::Import.create!(resource_key: "orders", filename: "secret-name.csv", status: "finished", result: { created: 1, updated: 0 })
      get "/admin/orders/imports/#{import.id}"
      expect(response.body).to include(">Import ##{import.id}<")                                            # import_status

      get "/admin/pages/maintenance"
      expect(response.body).to include("Housekeeping. Staff only.")                                        # custom_page
      get "/admin/nope"
      expect(response.body).to include("It may have been deleted.")                                        # error_page
    ensure
      I18n.backend.reload!
    end
  end
end
