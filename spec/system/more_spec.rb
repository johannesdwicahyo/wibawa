require "spec_helper"
require "tmpdir"

# The interactive features the first browser specs left out.
RSpec.describe "Wibawa in the browser, continued", type: :system do
  let!(:customer) { Customer.create!(name: "Sari") }
  let!(:orders) do
    [ [ "A-1", :pending ], [ "A-2", :paid ], [ "A-3", :pending ] ].map do |number, status|
      Order.create!(number: number, customer: customer, total: 10, status: status)
    end
  end

  def js(script) = page.evaluate_script(script)

  describe "searchable multi-select" do
    before { stub_const("Wibawa::ComboboxComponent::THRESHOLD", 0) }

    def chips = all("[data-wb-combo-chips] li").map { |chip| chip.find("span", match: :first).text }

    it "adds a chip per pick, removes with the button and with Backspace, and saves the set" do
      other = Customer.create!(name: "Budi")
      extra = Order.create!(number: "B-9", customer: other, total: 1)
      visit "/admin/customers/#{customer.id}/edit"
      expect(chips).to eq(%w[A-1 A-2 A-3])

      box = find("[data-wb-combobox][data-multiple] [role=combobox]")
      box.click
      box.set("B-9")
      expect(page).to have_css("[role=listbox] [role=option]", count: 1, text: "B-9")
      box.send_keys(:enter)
      expect(chips).to eq(%w[A-1 A-2 A-3 B-9])
      expect(page).to have_css("[role=listbox]", visible: :hidden) # the list closes, so it never covers Save
      expect(box.value).to eq("")

      box.set("B-9") # picking the same record again adds nothing
      expect(page).to have_css("[role=listbox] [role=option]", text: "B-9")
      box.send_keys(:enter)
      expect(chips).to eq(%w[A-1 A-2 A-3 B-9])

      find("[data-wb-combo-chips] li", text: "A-2").find("[data-wb-combo-remove]").click
      expect(chips).to eq(%w[A-1 A-3 B-9])
      box.click
      box.send_keys(:backspace) # in the empty box: takes back the last chip
      expect(chips).to eq(%w[A-1 A-3])

      box.set("B-9")
      expect(page).to have_css("[role=listbox] [role=option]", text: "B-9")
      box.send_keys(:enter)
      find("[data-wb-form] [type=submit]", match: :first).click
      expect(page).to have_no_css("[data-wb-form]")
      expect(customer.reload.orders.pluck(:number)).to contain_exactly("A-1", "A-3", "B-9")
      expect(extra.reload.customer).to eq(customer)
    end
  end

  describe "saved views" do
    before { Wibawa.config.saved_views = true }
    after { Wibawa.config.saved_views = false }

    it "saves the current filters under a name, applies the view from another page, and deletes it" do
      visit "/admin/orders"
      find("[data-wb-filters] summary").click
      select "Paid", from: "Status"
      click_button "Apply"
      expect(page).to have_css("tbody tr", count: 1)

      find("[data-wb-saved-views] summary").click
      within("[data-wb-saved-views]") do
        expect(page).to have_text("No saved views")
        find("input[name=name]").set("Paid only")
        click_button "Save"
      end
      expect(page).to have_css("[data-wb-saved-views] summary", text: "Paid only") # the button names the view in use
      expect(Wibawa::SavedView.pluck(:name, :query)).to eq([ [ "Paid only", "q%5Bstatus%5D=paid" ] ]) # no empty filters, no default page size

      visit "/admin/orders"
      expect(page).to have_css("tbody tr", count: 3)
      expect(page).to have_css("[data-wb-saved-views] summary", text: "Views")
      find("[data-wb-saved-views] summary").click
      click_link "Paid only"
      expect(page).to have_css("tbody tr", count: 1)
      expect(page).to have_css("ul[aria-label='Active filters'] a", text: "Paid")

      find("[data-wb-saved-views] summary").click
      accept_confirm { find("[data-wb-saved-views] button[aria-label='Delete view Paid only']").click }
      expect(page).to have_css("[data-wb-saved-views] summary", text: "Views")
      expect(Wibawa::SavedView.count).to eq(0)
    end

    it "opens one popover at a time" do
      visit "/admin/orders"
      find("[data-wb-filters] summary").click
      find("[data-wb-saved-views] summary").click
      expect(page).to have_css("[data-wb-saved-views][open]")
      expect(page).to have_css("[data-wb-filters]:not([open])")
    end
  end

  describe "CSV import" do
    # Plain files in a directory that outlives the example: a Tempfile can be
    # collected, and deleted, before the browser has read it.
    around { |example| Dir.mktmpdir { |dir| (@dir = dir) && example.run } }

    def csv(text)
      path = File.join(@dir, "orders-#{text.hash.abs}.csv")
      File.write(path, text)
      path
    end

    it "uploads a file, lists what is wrong by line, and imports nothing until it is right" do
      visit "/admin/orders"
      click_link "Import CSV"
      expect(page).to have_css("h1", text: "Import")

      attach_file "wb-import-file", csv("number,status,customer_id\nN-1,pending,#{customer.id}\n,paid,#{customer.id}\n")
      find("form[enctype='multipart/form-data'] [type=submit]").click
      expect(page).to have_css("[role=alert]", text: "Line 3")
      expect(Order.count).to eq(3)

      attach_file "wb-import-file", csv("number,status,customer_id\nN-1,pending,#{customer.id}\nA-1,paid,\n")
      find("form[enctype='multipart/form-data'] [type=submit]").click
      expect(page).to have_css("[data-wb-flash]", text: "1")
      expect(page).to have_current_path("/admin/orders")
      expect(Order.find_by(number: "N-1")).to be_pending
      expect(orders.first.reload).to be_paid # the existing A-1 was updated by its key
      expect(Order.count).to eq(4)
    end
  end

  describe "dragging a nested row" do
    it "reorders with a real mouse drag and saves the new order" do
      order = orders.first
      order.line_items.create!([ { product: "Tea", position: 1 }, { product: "Rice", position: 2 }, { product: "Salt", position: 3 } ])
      visit "/admin/orders/#{order.id}/edit"
      products = -> { js("[...document.querySelectorAll('[data-wb-nested-item] input[type=text]')].map((el) => el.value)") }
      center = lambda do |selector, index|
        js("(() => { const r = document.querySelectorAll('#{selector}')[#{index}].getBoundingClientRect(); return [r.x + r.width / 2, r.y + r.height / 2, r.bottom] })()")
      end

      from_x, from_y = center.call("[data-wb-drag-handle]", 0)
      to_x, _, to_bottom = center.call("[data-wb-nested-item]", 2)
      mouse = page.driver.browser.mouse
      mouse.move(x: from_x, y: from_y)
      mouse.down
      mouse.move(x: from_x + 5, y: from_y + 12, steps: 4) # far enough for the browser to start a drag
      mouse.move(x: to_x, y: to_bottom - 4, steps: 12)
      mouse.up

      expect(products.call).to eq(%w[Rice Salt Tea])
      expect(js("[...document.querySelectorAll('[data-wb-position]')].map((el) => el.value)")).to eq(%w[1 2 3])
      expect(page).to have_no_css("[data-wb-nested-item].opacity-50") # the drag ended cleanly

      find("[data-wb-form] [type=submit]", match: :first).click
      expect(page).to have_no_css("[data-wb-form]")
      expect(order.line_items.order(:position).pluck(:product)).to eq(%w[Rice Salt Tea])
    end
  end
end
