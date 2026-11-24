// Wibawa admin UI behaviour. No dependencies; all handlers are delegated from
// `document`, so they keep working across Turbo navigations and morphs.

const INDEX_FORM = "wb-index-form"
const THEME_KEY = "wibawa-theme"

const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector))

// ---- Sidebar (mobile) ------------------------------------------------------

function setSidebar(open) {
  const sidebar = document.querySelector("[data-wb-sidebar]")
  const backdrop = document.querySelector("[data-wb-sidebar-backdrop]")
  if (!sidebar) return
  sidebar.classList.toggle("-translate-x-full", !open)
  backdrop?.classList.toggle("hidden", !open)
  document.body.classList.toggle("overflow-hidden", open)
}

// ---- Filters popover ---------------------------------------------------------

const closeFilters = () => document.querySelector("details[data-wb-filters][open]")?.removeAttribute("open")

// ---- Theme -----------------------------------------------------------------

function toggleTheme() {
  const flip = () => {
    const dark = document.documentElement.classList.toggle("dark")
    try { localStorage.setItem(THEME_KEY, dark ? "dark" : "light") } catch (_) {}
  }
  // Cross-fade the two themes where the browser can; otherwise switch at once.
  document.startViewTransition ? document.startViewTransition(flip) : flip()
}

// ---- Batch selection -------------------------------------------------------

function syncBatchBar() {
  const boxes = $$("[data-wb-select]")
  const checked = boxes.filter((b) => b.checked)
  const bar = document.querySelector("[data-wb-batch-bar]")
  const all = document.querySelector("[data-wb-select-all]")
  if (bar) bar.hidden = checked.length === 0
  const count = document.querySelector("[data-wb-selected-count]")
  if (count) count.textContent = checked.length
  if (all) {
    all.checked = boxes.length > 0 && checked.length === boxes.length
    all.indeterminate = checked.length > 0 && checked.length < boxes.length
  }
}

let lastChecked = null

function handleSelect(box, shiftKey) {
  if (box.matches("[data-wb-select-all]")) {
    $$("[data-wb-select]").forEach((b) => { b.checked = box.checked })
  } else if (shiftKey && lastChecked && lastChecked !== box) {
    // Shift-click selects a range, like a mail client.
    const boxes = $$("[data-wb-select]")
    const [a, b] = [boxes.indexOf(lastChecked), boxes.indexOf(box)].sort((x, y) => x - y)
    boxes.slice(a, b + 1).forEach((el) => { el.checked = box.checked })
  }
  if (box.matches("[data-wb-select]")) lastChecked = box
  syncBatchBar()
}

// ---- Nested has_many fields ------------------------------------------------

function addNested(button) {
  const fieldset = button.closest("[data-wb-nested]")
  const template = fieldset.querySelector("template[data-wb-nested-template]")
  const list = fieldset.querySelector("[data-wb-nested-list]")
  const marker = fieldset.dataset.wbNewIndex
  const index = `${Date.now()}${Math.floor(Math.random() * 1000)}`
  const html = template.innerHTML.replaceAll(marker, index)
  list.insertAdjacentHTML("beforeend", html)
  renumber(fieldset)
  list.lastElementChild?.classList.add("wb-enter")
  list.lastElementChild?.querySelector("input:not([type=hidden]), select, textarea")?.focus()
}

function removeNested(button) {
  const item = button.closest("[data-wb-nested-item]")
  const destroy = item.querySelector("[data-wb-destroy]")
  const persisted = item.querySelector("input[name$='[id]']")
  if (persisted && destroy) {
    destroy.value = "1"
    item.hidden = true
  } else {
    item.remove()
  }
  renumber(button.closest("[data-wb-nested]") || document)
}

function renumber(fieldset) {
  let position = 1
  $$("[data-wb-nested-item]", fieldset).forEach((item) => {
    if (item.hidden) return
    const input = item.querySelector("[data-wb-position]")
    if (input) input.value = position++
  })
}

// Drag to reorder: the handle starts the drag, rows are drop targets.
let dragging = null

document.addEventListener("dragstart", (event) => {
  const handle = event.target.closest?.("[data-wb-drag-handle]")
  if (!handle) return
  dragging = handle.closest("[data-wb-nested-item]")
  dragging.classList.add("opacity-50")
  event.dataTransfer.effectAllowed = "move"
  event.dataTransfer.setDragImage(dragging, 20, 20)
})

document.addEventListener("dragover", (event) => {
  if (!dragging) return
  const over = event.target.closest?.("[data-wb-nested-item]")
  if (!over || over === dragging || over.parentElement !== dragging.parentElement) return
  event.preventDefault()
  const rect = over.getBoundingClientRect()
  const after = event.clientY > rect.top + rect.height / 2
  over.parentElement.insertBefore(dragging, after ? over.nextSibling : over)
})

document.addEventListener("dragend", () => {
  if (!dragging) return
  dragging.classList.remove("opacity-50")
  renumber(dragging.closest("[data-wb-nested]"))
  dragging = null
})

// ---- Delegated events ------------------------------------------------------

document.addEventListener("click", (event) => {
  const target = event.target.closest?.(
    "[data-wb-sidebar-open], [data-wb-sidebar-close], [data-wb-sidebar-backdrop], " +
    "[data-wb-theme-toggle], [data-wb-dismiss], [data-wb-nested-add], [data-wb-nested-remove]"
  )
  if (!event.target.closest?.("[data-wb-filters]")) closeFilters()
  if (!target) return

  if (target.matches("[data-wb-sidebar-open]")) setSidebar(true)
  else if (target.matches("[data-wb-sidebar-close]")) setSidebar(false)
  else if (target.matches("[data-wb-sidebar-backdrop]")) setSidebar(false)
  else if (target.matches("[data-wb-theme-toggle]")) toggleTheme()
  else if (target.matches("[data-wb-dismiss]")) target.closest("[data-wb-flash]")?.remove()
  else if (target.matches("[data-wb-nested-add]")) addNested(target)
  else if (target.matches("[data-wb-nested-remove]")) removeNested(target)
})

document.addEventListener("change", (event) => {
  const el = event.target
  if (el.matches("[data-wb-select], [data-wb-select-all]")) handleSelect(el, false)
  if (el.matches("[data-wb-autosubmit]") && el.form) el.form.requestSubmit()
})

// Remember shift for range selection (change events don't carry modifier keys).
document.addEventListener("click", (event) => {
  const box = event.target.closest?.("[data-wb-select]")
  if (box && event.shiftKey) handleSelect(box, true)
}, true)

// Enter in any input attached to the index form submits it, even though the
// form holds several text inputs (where browsers skip implicit submission).
document.addEventListener("keydown", (event) => {
  const el = event.target
  if (event.key === "Enter" && el.matches?.(`input[form="${INDEX_FORM}"]`)) {
    event.preventDefault()
    el.form?.requestSubmit()
  }
  if (event.key === "Escape") {
    setSidebar(false)
    closeFilters()
  }
  // "/" focuses the index search box.
  if (event.key === "/" && !el.matches?.("input, textarea, select, [contenteditable]")) {
    const search = document.querySelector("[data-wb-search]")
    if (search) { event.preventDefault(); search.focus(); search.select() }
  }
})

document.addEventListener("turbo:load", () => {
  setSidebar(false)
  syncBatchBar()
  lastChecked = null
})
// After a failed save, put the cursor in the first field that needs fixing.
document.addEventListener("turbo:render", () => document.querySelector('[data-wb-form] [aria-invalid="true"]')?.focus())
document.addEventListener("turbo:morph", syncBatchBar)

// The button that submitted a form shows a spinner until the response arrives.
document.addEventListener("turbo:submit-start", (event) => event.detail.formSubmission.submitter?.setAttribute("data-wb-busy", ""))
document.addEventListener("turbo:submit-end", (event) => {
  if (!event.detail.success) event.detail.formSubmission.submitter?.removeAttribute("data-wb-busy")
})
