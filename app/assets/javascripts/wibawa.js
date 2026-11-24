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

// Filters and saved views. One open at a time; a click elsewhere or Escape closes them.
const closePopovers = (except) => $$("details[data-wb-popover][open]").forEach((el) => { if (el !== except) el.removeAttribute("open") })

// ---- Command palette (Cmd/Ctrl+K) ------------------------------------------

const palette = () => document.querySelector("[data-wb-palette]")
let searchTimer = null
let searching = false

function setActiveOption(option) {
  $$("[aria-selected=true]", palette()).forEach((el) => el.setAttribute("aria-selected", "false"))
  option?.setAttribute("aria-selected", "true")
  option?.scrollIntoView({ block: "nearest" })
}

// Selects the first visible option and shows "no matches" when there is none.
function refreshPalette() {
  const dialog = palette()
  const options = $$("[role=option]:not([hidden])", dialog)
  setActiveOption(options[0])
  dialog.querySelector("[data-wb-palette-empty]").hidden = options.length > 0 || searching
}

// Pages filter in the browser; records come from the server after a short pause.
function filterPalette() {
  const dialog = palette()
  const input = dialog.querySelector("[data-wb-palette-input]")
  const results = dialog.querySelector("[data-wb-palette-results]")
  const term = input.value.trim().toLowerCase()

  $$("[data-wb-palette-static] [role=option]", dialog).forEach((el) => { el.hidden = !el.textContent.toLowerCase().includes(term) })
  clearTimeout(searchTimer)
  results.innerHTML = ""
  searching = term.length >= 2
  if (searching) {
    searchTimer = setTimeout(async () => {
      let html = ""
      try {
        const response = await fetch(`${input.dataset.searchUrl}?q=${encodeURIComponent(term)}`, { headers: { Accept: "text/html" } })
        if (response.ok) html = await response.text()
      } catch (_) {}
      if (input.value.trim().toLowerCase() !== term) return // a newer search is on its way
      results.innerHTML = html
      searching = false
      refreshPalette()
    }, 200)
  }
  refreshPalette()
}

function openPalette() {
  const dialog = palette()
  if (!dialog || dialog.open) return
  setSidebar(false)
  dialog.showModal()
  dialog.querySelector("[data-wb-palette-input]").value = ""
  filterPalette()
}

function movePalette(step) {
  const options = $$("[role=option]:not([hidden])", palette())
  if (!options.length) return
  const index = options.findIndex((el) => el.getAttribute("aria-selected") === "true")
  setActiveOption(options[(index + step + options.length) % options.length])
}

document.addEventListener("input", (event) => {
  if (event.target.matches("[data-wb-palette-input]")) filterPalette()
})

document.addEventListener("pointermove", (event) => {
  const option = event.target.closest?.("[data-wb-palette] [role=option]")
  if (option && option.getAttribute("aria-selected") !== "true") setActiveOption(option)
})

document.addEventListener("keydown", (event) => {
  if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
    event.preventDefault()
    openPalette()
  } else if (event.target.matches?.("[data-wb-palette-input]")) {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      movePalette(event.key === "ArrowDown" ? 1 : -1)
    } else if (event.key === "Enter") {
      event.preventDefault()
      palette().querySelector("[aria-selected=true] a")?.click()
    }
  }
})

document.addEventListener("click", (event) => {
  if (event.target.closest?.("[data-wb-palette-open]")) openPalette()
  else if (event.target.matches?.("dialog[data-wb-palette]")) event.target.close() // the backdrop
})

// Turbo keeps a snapshot of the page for Back; it must not remember the palette as open.
document.addEventListener("turbo:before-cache", () => palette()?.close())

// ---- Searchable select (combobox) -----------------------------------------
// The text box shows the chosen record's name; a hidden input next to it holds the id.

let comboTimer = null

function comboParts(el) {
  const root = el.closest("[data-wb-combobox]")
  return root && {
    root,
    input: root.querySelector("[role=combobox]"),
    hidden: root.querySelector("input[type=hidden]"),
    list: root.querySelector("[role=listbox]"),
  }
}

function closeCombo({ input, list }) {
  list.hidden = true
  input.setAttribute("aria-expanded", "false")
}

function comboActive(list, option) {
  $$("[aria-selected=true]", list).forEach((el) => el.setAttribute("aria-selected", "false"))
  option?.setAttribute("aria-selected", "true")
  option?.scrollIntoView({ block: "nearest" })
}

function loadCombo(parts, term, delay) {
  clearTimeout(comboTimer)
  comboTimer = setTimeout(async () => {
    let html = ""
    try {
      const response = await fetch(`${parts.root.dataset.url}?q=${encodeURIComponent(term)}`, { headers: { Accept: "text/html" } })
      if (response.ok) html = await response.text()
    } catch (_) {}
    if (document.activeElement !== parts.input) return // moved on while it loaded
    parts.list.innerHTML = html
    parts.list.hidden = false
    parts.input.setAttribute("aria-expanded", "true")
    comboActive(parts.list, parts.list.querySelector("[role=option]"))
  }, delay)
}

function pickCombo(parts, option) {
  parts.hidden.value = option.dataset.value
  parts.input.value = parts.input.dataset.label = option.textContent.trim()
  closeCombo(parts)
  parts.hidden.dispatchEvent(new Event("change", { bubbles: true }))
}

document.addEventListener("focusin", (event) => {
  const parts = event.target.matches?.("[data-wb-combobox] [role=combobox]") && comboParts(event.target)
  if (!parts) return
  parts.input.select()
  loadCombo(parts, "", 0)
})

document.addEventListener("input", (event) => {
  const parts = event.target.matches?.("[data-wb-combobox] [role=combobox]") && comboParts(event.target)
  if (parts) loadCombo(parts, parts.input.value.trim(), 200)
})

// Leaving the box: empty text clears the choice, anything else goes back to the chosen name.
document.addEventListener("focusout", (event) => {
  const parts = event.target.matches?.("[data-wb-combobox] [role=combobox]") && comboParts(event.target)
  if (!parts) return
  clearTimeout(comboTimer)
  if (parts.input.value.trim() === "") parts.hidden.value = parts.input.dataset.label = ""
  parts.input.value = parts.input.dataset.label
  closeCombo(parts)
})

// pointerdown rather than click: it comes before the text box loses focus.
document.addEventListener("pointerdown", (event) => {
  const option = event.target.closest?.("[data-wb-combobox] [role=option]")
  if (!option) return
  event.preventDefault()
  pickCombo(comboParts(option), option)
})

document.addEventListener("keydown", (event) => {
  const parts = event.target.matches?.("[data-wb-combobox] [role=combobox]") && comboParts(event.target)
  if (!parts || parts.list.hidden) return
  const options = $$("[role=option]", parts.list)
  const index = options.findIndex((el) => el.getAttribute("aria-selected") === "true")
  if (event.key === "ArrowDown" || event.key === "ArrowUp") {
    event.preventDefault()
    if (options.length) comboActive(parts.list, options[(index + (event.key === "ArrowDown" ? 1 : -1) + options.length) % options.length])
  } else if (event.key === "Enter") {
    event.preventDefault() // never submit the form from an open list
    if (options[index]) pickCombo(parts, options[index])
  } else if (event.key === "Escape") {
    event.stopPropagation()
    closeCombo(parts)
  }
}, true)

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
  closePopovers(event.target.closest?.("details[data-wb-popover]"))
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
    closePopovers()
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
  const mac = /Mac|iPhone|iPad/.test(navigator.platform)
  $$("[data-wb-palette-kbd]").forEach((el) => { el.textContent = mac ? "⌘K" : "Ctrl K" })
})
// After a failed save, put the cursor in the first field that needs fixing.
document.addEventListener("turbo:render", () => document.querySelector('[data-wb-form] [aria-invalid="true"]')?.focus())
document.addEventListener("turbo:morph", syncBatchBar)

// The button that submitted a form shows a spinner until the response arrives.
document.addEventListener("turbo:submit-start", (event) => event.detail.formSubmission.submitter?.setAttribute("data-wb-busy", ""))
document.addEventListener("turbo:submit-end", (event) => {
  if (!event.detail.success) event.detail.formSubmission.submitter?.removeAttribute("data-wb-busy")
})
