require "spec_helper"

# The JavaScript in app/assets/javascripts/wibawa.js, in a real browser.
RSpec.describe "Wibawa in the browser", type: :system do
  let!(:customer) { Customer.create!(name: "Sari") }
  let!(:orders) do
    [["A-1", :pending], ["A-2", :paid], ["A-3", :pending]].map do |number, status|
      Order.create!(number: number, customer: customer, total: 10, status: status)
    end
  end

  def js(script) = page.evaluate_script(script)

  describe "nested rows" do
    def products = js("[...document.querySelectorAll(\x27[data-wb-nested-item]\x27)].filter((row) => !row.hidden).map((row) => row.querySelector(\x27input[type=text]\x27).value)")

    # A real drag needs the operating system; these are the events the browser would send.
    def drag(from, to)
      page.execute_script(<<~JS, from, to)
        const rows = [...document.querySelectorAll("[data-wb-nested-item]")].filter((row) => !row.hidden)
        const [source, target] = [rows[arguments[0]], rows[arguments[1]]]
        const data = new DataTransfer()
        const rect = target.getBoundingClientRect()
        source.querySelector("[data-wb-drag-handle]").dispatchEvent(new DragEvent("dragstart", { bubbles: true, dataTransfer: data }))
        target.dispatchEvent(new DragEvent("dragover", { bubbles: true, cancelable: true, dataTransfer: data, clientY: rect.bottom - 1 }))
        source.dispatchEvent(new DragEvent("dragend", { bubbles: true }))
      JS
    end

    it "adds, reorders and removes rows, and saves them in order" do
      visit "/admin/orders/new"
      fill_in "Number", with: "N-1"
      select "Sari", from: "Customer"

      %w[Tea Rice Salt].each do |product|
        find("[data-wb-nested-add]").click
        expect(page).to have_css("[data-wb-nested-item]:last-child input:focus") # the new row takes the cursor
        all("[data-wb-nested-item] input[type=text]").last.set(product)
      end

      drag 0, 2 # Tea to the end
      expect(products).to eq(%w[Rice Salt Tea])
      all("[data-wb-nested-remove]")[1].click # Salt, never saved: gone from the page
      expect(products).to eq(%w[Rice Tea])

      find("[data-wb-form] [type=submit]", match: :first).click
      expect(page).to have_no_css("[data-wb-form]")
      expect(Order.find_by!(number: "N-1").line_items.order(:position).pluck(:product, :position)).to eq([["Rice", 1], ["Tea", 2]])
    end

    it "deletes a saved row only when the form is saved" do
      order = orders.first
      order.line_items.create!([{ product: "Tea", position: 1 }, { product: "Rice", position: 2 }])
      visit "/admin/orders/#{order.id}/edit"

      all("[data-wb-nested-remove]").first.click
      expect(products).to eq(%w[Rice])
      expect(order.line_items.count).to eq(2)

      find("[data-wb-form] [type=submit]", match: :first).click
      expect(page).to have_no_css("[data-wb-form]")
      expect(order.line_items.reload.pluck(:product, :position)).to eq([["Rice", 1]])
    end
  end

  describe "batch selection" do
    it "counts the selection, selects all and a shift-click range, and deletes" do
      visit "/admin/orders"
      boxes = all("[data-wb-select]")
      expect(page).to have_css("[data-wb-batch-bar]", visible: :hidden)

      boxes[0].click
      expect(find("[data-wb-batch-bar]")).to have_text("1 selected")
      expect(js("document.querySelector('[data-wb-select-all]').indeterminate")).to be(true)

      boxes[2].click(:shift)
      expect(find("[data-wb-batch-bar]")).to have_text("3 selected")
      expect(find("[data-wb-select-all]")).to be_checked

      find("[data-wb-select-all]").click
      expect(page).to have_css("[data-wb-batch-bar]", visible: :hidden)

      boxes[1].click
      accept_confirm { find("[data-wb-batch-bar] button[value=destroy]").click }
      expect(page).to have_css("[data-wb-select]", count: 2)
      expect(Order.pluck(:number)).to contain_exactly("A-1", "A-3")
      expect(page).to have_css("[data-wb-batch-bar]", visible: :hidden)
    end
  end

  describe "filters" do
    it "applies a filter from the popover and removes it by its chip" do
      visit "/admin/orders"
      find("[data-wb-filters] summary").click
      select "Paid", from: "Status"
      click_button "Apply"
      expect(page).to have_css("tbody tr", count: 1)
      expect(page).to have_css("[data-wb-filters]:not([open])")

      chip = find("ul[aria-label='Active filters'] a")
      expect(chip).to have_text("Paid")
      chip.click
      expect(page).to have_css("tbody tr", count: 3)
    end

    it "closes on Escape and on a click outside" do
      visit "/admin/orders"
      find("[data-wb-filters] summary").click
      expect(page).to have_css("[data-wb-filters][open]")
      find("body").send_keys(:escape)
      expect(page).to have_css("[data-wb-filters]:not([open])")

      find("[data-wb-filters] summary").click
      find("h1").click
      expect(page).to have_css("[data-wb-filters]:not([open])")
    end
  end

  describe "theme" do
    it "switches to dark and remembers it" do
      visit "/admin"
      expect(page).to have_no_css("html.dark")
      find("[data-wb-theme-toggle]").click
      expect(page).to have_css("html.dark")

      visit "/admin/orders"
      expect(page).to have_css("html.dark")
      find("[data-wb-theme-toggle]").click
      expect(page).to have_no_css("html.dark")
    end
  end

  describe "sidebar on a phone" do
    it "opens from the menu button and closes on Escape, the backdrop and navigation" do
      page.current_window.resize_to(390, 800)
      visit "/admin"
      expect(page).to have_css("[data-wb-sidebar].-translate-x-full")

      find("[data-wb-sidebar-open]").click
      expect(page).to have_no_css("[data-wb-sidebar].-translate-x-full")
      find("body").send_keys(:escape)
      expect(page).to have_css("[data-wb-sidebar].-translate-x-full")

      find("[data-wb-sidebar-open]").click
      page.driver.browser.mouse.click(x: 320, y: 400) # the backdrop, right of the open sidebar
      expect(page).to have_css("[data-wb-sidebar].-translate-x-full")

      find("[data-wb-sidebar-open]").click
      within("[data-wb-sidebar]") { click_link "Orders" }
      expect(page).to have_current_path("/admin/orders")
      expect(page).to have_css("[data-wb-sidebar].-translate-x-full")
      expect(js("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
    end
  end

  describe "sidebar rail" do
    it "collapses to icons and stays collapsed on the next page" do
      visit "/admin"
      width = -> { js("document.querySelector('[data-wb-sidebar]').getBoundingClientRect().width") }
      expect(width.call).to eq(256)

      find("[data-wb-rail-toggle]").click
      expect(page).to have_css("[data-wb-rail-toggle][aria-pressed=true]")
      expect(width.call).to eq(56)
      expect(page).to have_no_css("[data-wb-sidebar] nav span", text: "Orders")

      find("[data-wb-sidebar] nav a[title=Orders]").click
      expect(page).to have_current_path("/admin/orders")
      expect(width.call).to eq(56)
      find("[data-wb-rail-toggle]").click
      expect(width.call).to eq(256)
    end
  end

  describe "index table" do
    it "keeps its header in view while the rows scroll, and honours compact density" do
      60.times { |i| Order.create!(number: "S-#{i}", customer: customer, total: 1) }
      visit "/admin/orders"
      top = js(<<~JS)
        (() => {
          const box = document.querySelector("[data-wb-table] .overflow-auto")
          box.scrollTop = 800
          return [box.scrollTop, Math.round(box.querySelector("th").getBoundingClientRect().top - box.getBoundingClientRect().top),
                  Math.round(box.querySelector("tbody tr").getBoundingClientRect().height)]
        })()
      JS
      expect(top).to eq([800, 0, 40])

      orders.first.line_items.create!(product: "Tea", position: 1)
      visit "/admin/line_items"
      expect(js("Math.round(document.querySelector('tbody tr').getBoundingClientRect().height)")).to eq(32)
    end
  end

  describe "page actions on a phone" do
    it "folds secondary actions into a menu and keeps the first column in view" do
      page.current_window.resize_to(390, 800)
      visit "/admin/orders"
      expect(page).to have_css("header a", text: "New Order", count: 1)
      expect(page).to have_no_css("header a", text: "Import CSV")

      find("[data-wb-more] summary").click
      expect(page).to have_css("[data-wb-more] a", text: "Import CSV")
      find("body").send_keys(:escape)
      expect(page).to have_css("[data-wb-more]:not([open])")

      left = js(<<~JS)
        (() => {
          const box = document.querySelector("[data-wb-table] .overflow-auto")
          box.scrollLeft = 200
          return [box.scrollLeft > 0, Math.round(box.querySelector("tbody td:nth-child(2)").getBoundingClientRect().left - box.getBoundingClientRect().left)]
        })()
      JS
      expect(left).to eq([true, 0])
      expect(js("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
    end
  end

  describe "uploads and rich text" do
    it "attaches a file and saves what was typed in the editor" do
      visit "/admin/products/new"
      fill_in "Name", with: "Kain"
      attach_file "Photo", File.expand_path("../fixtures/files/kawung.png", __dir__)
      expect(page).to have_css("trix-toolbar button", minimum: 5) # the editor loaded
      find("trix-editor").click
      find("trix-editor").send_keys("Hand drawn in Solo")
      find("[data-wb-form] [type=submit]", match: :first).click

      expect(page).to have_no_css("[data-wb-form]")
      product = Product.last
      expect(product.photo).to be_attached
      expect(product.description.to_plain_text).to eq("Hand drawn in Solo")
      expect(page).to have_css("img[src*='/rails/active_storage/']")
      expect(page).to have_text("Hand drawn in Solo")
    end
  end

  describe "command palette" do
    it "opens on Ctrl+K, filters pages, finds records and follows Enter" do
      visit "/admin"
      find("body").send_keys([:control, "k"])
      expect(page).to have_css("dialog[data-wb-palette][open]")

      input = find("[data-wb-palette-input]")
      input.set("cust")
      expect(page).to have_css("[data-wb-palette-static] [role=option]", text: "Customers")
      expect(page).to have_no_css("[data-wb-palette-static] [role=option]", text: "Line items")

      input.set("A-2")
      expect(page).to have_css("[data-wb-palette-results] [role=option]", text: "A-2")
      input.send_keys(:enter)
      expect(page).to have_current_path("/admin/orders/#{orders[1].id}")
      expect(page).to have_no_css("dialog[data-wb-palette][open]")
    end
  end

  describe "searchable select" do
    before { stub_const("Wibawa::ComboboxComponent::THRESHOLD", 0) }

    it "searches as you type and saves the pick" do
      other = Customer.create!(name: "Budi")
      visit "/admin/orders/#{orders.first.id}/edit"

      box = find("[data-wb-combobox] [role=combobox]", match: :first)
      box.click
      expect(page).to have_css("[role=listbox] [role=option]", minimum: 2)
      box.set("bud")
      expect(page).to have_css("[role=listbox] [role=option]", count: 1, text: "Budi")
      box.send_keys(:enter)
      expect(page).to have_css("[role=listbox]", visible: :hidden)
      expect(box.value).to eq("Budi")

      find("[data-wb-form] [type=submit]", match: :first).click
      expect(page).to have_no_css("[data-wb-form]")
      expect(orders.first.reload.customer).to eq(other)
    end
  end
end
