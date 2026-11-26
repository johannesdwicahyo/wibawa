require "spec_helper"
require "tmpdir"

# Every kind of page, checked by axe-core against WCAG 2.2 A and AA, in both
# themes and at desktop and phone width. axe finds what a machine can find
# (contrast, names, roles, structure); the keyboard specs below cover the rest.
RSpec.describe "Wibawa accessibility", type: :system do
  AXE = File.expand_path("../../node_modules/axe-core/axe.min.js", __dir__)
  TAGS = %w[wcag2a wcag2aa wcag21a wcag21aa wcag22aa].freeze

  let!(:customer) { Customer.create!(name: "Sari") }
  let!(:order) { Order.create!(number: "A-1", customer: customer, total: 10, status: :paid) }

  before do
    skip "run `npm install` to get axe-core" unless File.exist?(AXE)
    Order.create!(number: "A-2", customer: customer, total: 15)
    order.line_items.create!(product: "Tea", position: 1)
  end

  def violations
    page.execute_script(File.read(AXE)) unless page.evaluate_script("typeof axe") == "object"
    result = page.evaluate_async_script(<<~JS, TAGS)
      const done = arguments[arguments.length - 1]
      axe.run(document, { runOnly: { type: "tag", values: arguments[0] } }).then((r) => done(r.violations.map((v) =>
        v.id + ": " + v.nodes.slice(0, 3).map((n) => n.target.join(" ") + " (" + (n.any[0] || n.all[0] || n.none[0] || {}).message + ")").join("; "))))
    JS
    result
  end

  def dark! = page.execute_script("localStorage.setItem('wibawa-theme', 'dark'); document.documentElement.classList.add('dark')")

  PAGES = {
    "dashboard" => "/admin",
    "index" => "/admin/orders",
    "show" => "/admin/orders/%<id>s",
    "show with history" => "/admin/customers/%<customer>s",
    "form" => "/admin/orders/%<id>s/edit",
    "has_many form" => "/admin/customers/new",
    "bar report" => "/admin/reports/orders_by_status",
    "line report" => "/admin/reports/total_and_double",
    "import" => "/admin/orders/import",
    "custom page" => "/admin/pages/maintenance"
  }.freeze

  { "desktop" => [ 1280, 900 ], "phone" => [ 390, 800 ] }.each do |size, (width, height)|
    %w[light dark].each do |theme|
      it "has no axe violations on any page (#{size}, #{theme})" do
        page.current_window.resize_to(width, height)
        found = PAGES.flat_map do |name, path|
          visit format(path, id: order.id, customer: order.customer_id)
          if theme == "dark"
            dark!
            visit format(path, id: order.id, customer: order.customer_id)
          end
          violations.map { |violation| "#{name}: #{violation}" }
        end
        expect(found).to eq([])
      end
    end
  end

  it "would notice a problem" do
    visit "/admin"
    page.execute_script(%q{document.querySelector("main").insertAdjacentHTML("beforeend", '<button></button><p style="color:#999;background:#fff">faint</p>')})
    expect(violations.join).to include("button-name", "color-contrast")
  end

  it "has no axe violations with the filters, the batch bar, the palette, a saved view's edit panel, an import check and form errors showing" do
    found = []
    visit "/admin/orders"
    all("[data-wb-select]").first.click
    find("[data-wb-filters] summary").click
    found += violations.map { |violation| "filters and batch bar: #{violation}" }

    find("body").send_keys(:escape)
    find("body").send_keys([ :control, "k" ])
    expect(page).to have_css("dialog[data-wb-palette][open]")
    sleep 0.3 # let the dialog finish fading in, or contrast is measured mid-fade
    found += violations.map { |violation| "palette: #{violation}" }

    find("body").send_keys(:escape)
    find("[data-wb-rail-toggle]").click
    found += violations.map { |violation| "sidebar rail: #{violation}" }
    find("[data-wb-rail-toggle]").click

    Wibawa.config.saved_views = true
    Wibawa::SavedView.create!(resource_key: "orders", name: "Paid", query: "q%5Bstatus%5D=paid", shared: true, default_view: true)
    [ false, true ].each do |dark|
      visit "/admin/orders?search=x"
      dark! if dark
      find("[data-wb-saved-views] > summary").click
      find("[data-wb-view-edit] summary").click
      found += violations.map { |violation| "saved view edit panel#{' (dark)' if dark}: #{violation}" }
    end
    page.execute_script("localStorage.clear()")

    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "orders.csv"), "number,status,customer_id\nN-1,paid,#{order.customer_id}\n#{order.number},paid,\n")
      visit "/admin/orders/import"
      attach_file "wb-import-file", File.join(dir, "orders.csv")
      click_button "Check file"
      expect(page).to have_css("[data-wb-import-preview]")
      found += violations.map { |violation| "import check: #{violation}" }
    end

    visit "/admin/orders/new"
    page.execute_script("document.querySelectorAll('form').forEach((form) => { form.noValidate = true })")
    find("[data-wb-form] [type=submit]", match: :first).click
    expect(page).to have_css("[role=alert]")
    found += violations.map { |violation| "form errors: #{violation}" }

    expect(found.join("\n")).to eq("")
  ensure
    Wibawa.config.saved_views = false
  end

  describe "keyboard" do
    def focused = page.evaluate_script("document.activeElement.outerHTML.slice(0, 160)")

    it "offers a skip link first, which moves focus to the content" do
      visit "/admin/orders"
      find("body").send_keys(:tab)
      expect(page.evaluate_script("document.activeElement.textContent")).to eq("Skip to content")
      page.driver.browser.keyboard.type(:enter)
      expect(page.evaluate_script("document.activeElement.id")).to eq("wb-main")
    end

    it "reorders nested rows with the arrow keys and the arrow buttons, no drag needed" do
      order.line_items.create!(product: "Rice", position: 2)
      visit "/admin/orders/#{order.id}/edit"
      products = -> { page.evaluate_script("[...document.querySelectorAll('[data-wb-nested-item] input[type=text]')].map((el) => el.value)") }

      all("[data-wb-drag-handle]").first.send_keys(:down)
      expect(products.call).to eq(%w[Rice Tea])
      expect(focused).to include("data-wb-drag-handle") # focus travels with the row

      all("[data-wb-nested-move=up]").last.click
      expect(products.call).to eq(%w[Tea Rice])
      find("[data-wb-form] [type=submit]", match: :first).click
      expect(page).to have_no_css("[data-wb-form]")
      expect(order.line_items.order(:position).pluck(:product)).to eq(%w[Tea Rice])
    end

    it "returns focus to the Filters button when Escape closes the popover" do
      visit "/admin/orders"
      find("[data-wb-filters] summary").click
      find("#wb-filter-status").click
      find("#wb-filter-status").send_keys(:escape)
      expect(page).to have_css("[data-wb-filters]:not([open])")
      expect(focused).to start_with("<summary")
    end

    it "names the active palette option for screen readers and keeps links out of the tab order" do
      visit "/admin"
      find("body").send_keys([ :control, "k" ])
      input = find("[data-wb-palette-input]")
      first_id = input["aria-activedescendant"]
      expect(page).to have_css("##{first_id}[role=option][aria-selected=true]")
      input.send_keys(:down)
      expect(input["aria-activedescendant"]).not_to eq(first_id)
      expect(page).to have_no_css("[data-wb-palette] a:not([tabindex='-1'])")
    end

    it "does not let a disabled page link be followed" do
      visit "/admin/orders"
      expect(page).to have_css("a[rel=prev][aria-disabled=true]:not([href])")
    end
  end

  # Elements that cut off their own text: content wider or taller than a box that hides overflow.
  # Marked truncation (an ellipsis, a scroll area) is deliberate and left out.
  CLIPPED = <<~JS.freeze
    [...document.querySelectorAll("main *, [data-wb-sidebar] *")].filter((el) => {
      if (!el.childNodes.length || !el.offsetParent || !el.textContent.trim()) return false
      const style = getComputedStyle(el)
      if (style.textOverflow === "ellipsis" || el.closest(".sr-only, .truncate, [hidden]")) return false
      const hidesX = ["hidden", "clip"].includes(style.overflowX), hidesY = ["hidden", "clip"].includes(style.overflowY)
      return (hidesX && el.scrollWidth > el.clientWidth + 1) || (hidesY && el.scrollHeight > el.clientHeight + 1)
    }).map((el) => el.tagName.toLowerCase() + "." + [...el.classList].slice(0, 3).join(".") + ": " + el.textContent.trim().slice(0, 30))
  JS

  def problems(name)
    found = page.evaluate_script(CLIPPED).map { |element| "#{name}: clipped #{element}" }
    found << "#{name}: scrolls sideways" unless page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    found
  end

  it "would notice clipped text and sideways scrolling" do
    visit "/admin"
    expect(problems("page")).to eq([])
    page.execute_script(%q{document.querySelector("main").insertAdjacentHTML("beforeend", '<p style="width:40px;overflow:hidden;white-space:nowrap">A long line that cannot fit</p><div style="width:200vw">wide</div>')})
    expect(problems("page")).to contain_exactly(a_string_including("clipped p", "A long line"), "page: scrolls sideways")
  end

  it "loses no text when the reader widens line, paragraph, letter and word spacing (WCAG 1.4.12)" do
    spacing = "* { line-height: 1.5 !important; letter-spacing: 0.12em !important; word-spacing: 0.16em !important; } p { margin-bottom: 2em !important; }"
    found = PAGES.flat_map do |name, path|
      visit format(path, id: order.id, customer: order.customer_id)
      page.execute_script("document.head.insertAdjacentHTML('beforeend', '<style>#{spacing}</style>')")
      problems(name)
    end
    expect(found.join("\n")).to eq("")
  end

  it "stays usable with text at 200% (WCAG 1.4.4)" do
    found = PAGES.flat_map do |name, path|
      visit format(path, id: order.id, customer: order.customer_id)
      page.execute_script("document.documentElement.style.fontSize = '200%'")
      problems(name)
    end
    expect(found.join("\n")).to eq("")
  end

  it "stays usable at 200% browser zoom, which halves the window to 640 px" do
    page.current_window.resize_to(640, 450)
    found = PAGES.flat_map do |name, path|
      visit format(path, id: order.id, customer: order.customer_id)
      heading = page.evaluate_script("(() => { const r = document.querySelector('h1').getBoundingClientRect(); return r.left >= 0 && r.right <= innerWidth })()")
      problems(name) + (heading ? [] : [ "#{name}: the page title is cut off" ])
    end
    expect(found.join("\n")).to eq("")
  end

  it "fits a 320 px wide screen without sideways scrolling" do
    page.current_window.resize_to(320, 700)
    wide = PAGES.filter_map do |name, path|
      visit format(path, id: order.id, customer: order.customer_id)
      name unless page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")
    end
    expect(wide).to eq([])
  end
end
