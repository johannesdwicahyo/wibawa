module Wibawa
  module ApplicationHelper
    BUTTON_BASE = "inline-flex items-center justify-center gap-1.5 rounded-control px-3 py-2 text-sm font-semibold " \
                  "transition active:scale-[.985] pointer-coarse:min-h-11 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary " \
                  "disabled:opacity-50 disabled:pointer-events-none cursor-pointer whitespace-nowrap".freeze
    BUTTON_STYLES = {
      primary: "bg-primary text-on-primary hover:bg-primary/90",
      secondary: "bg-surface text-ink ring-1 ring-inset ring-line hover:bg-surface-2",
      danger: "bg-surface text-rose-700 ring-1 ring-inset ring-rose-300 hover:bg-rose-50 " \
              "dark:bg-rose-500/10 dark:text-rose-300 dark:ring-rose-500/30 dark:hover:bg-rose-500/20",
      ghost: "text-ink-2 hover:bg-surface-2 hover:text-ink"
    }.freeze

    INPUT_CLASS = "block w-full rounded-control border-0 bg-surface px-3 py-2 text-sm text-ink ring-1 ring-inset " \
                  "ring-line placeholder:text-ink-3 focus:ring-2 focus:ring-inset focus:ring-primary dark:[color-scheme:dark]".freeze
    INPUT_ERROR_CLASS = "ring-rose-400 focus:ring-rose-500 dark:ring-rose-500/60".freeze

    MARK_PATH = "M12,12 H38 A74,74 0 0 1 112,86 V112 H86 A74,74 0 0 1 12,38 Z M244,12 V38 A74,74 0 0 1 170,112 H144 V86 A74,74 0 0 1 218,12 Z M112,144 V170 A74,74 0 0 1 38,244 H12 V218 A74,74 0 0 1 86,144 Z M144,144 H170 A74,74 0 0 1 244,218 V244 H218 A74,74 0 0 1 144,170 Z M128,104 L152,128 L128,152 L104,128 Z".freeze
    FONT_LATIN_RANGE = "U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD".freeze
    FONT_LATIN_EXT_RANGE = "U+0100-02BA,U+02BD-02C5,U+02C7-02CC,U+02CE-02D7,U+02DD-02FF,U+0304,U+0308,U+0329,U+1D00-1DBF,U+1E00-1E9F,U+1EF2-1EFF,U+2020,U+20A0-20AB,U+20AD-20C0,U+2113,U+2C60-2C7F,U+A720-A7FF".freeze

    # Stroke icons drawn on a 20×20 grid.
    ICONS = {
      "home" => "M3 10.5 10 4l7 6.5M5 9v8h4v-4.5h2V17h4V9",
      "table" => "M3 4.5h14v11H3zM3 8.5h14M3 12h14M8 8.5v7",
      "users" => "M7.5 9.5a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM2 17c0-3 2.4-5 5.5-5s5.5 2 5.5 5M13.5 3.8a3 3 0 0 1 0 5.4M15.5 12.3c1.6.6 2.5 2.3 2.5 4.7",
      "receipt" => "M5 2.5h10v15l-2.5-1.5-2.5 1.5-2.5-1.5L5 17.5zM8 6.5h4M8 9.5h4M8 12.5h2",
      "box" => "M3 6.2 10 3l7 3.2v7.6L10 17l-7-3.2zM3 6.2 10 9.4l7-3.2M10 9.4V17",
      "cog" => "M10 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM10 2v2.2M10 15.8V18M2 10h2.2M15.8 10H18M4.3 4.3l1.6 1.6M14.1 14.1l1.6 1.6M4.3 15.7l1.6-1.6M14.1 5.9l1.6-1.6",
      "chart" => "M3 17h14M6 14V9.5M10 14V5M14 14v-3.5",
      "tag" => "M3 3h7l7.5 7.5-7 7L3 10zM7 7h.01",
      "store" => "M3.5 8 5 3.5h10L16.5 8M4 8v9h12V8M3.5 8a2.2 2.2 0 0 0 4.3 0 2.2 2.2 0 0 0 4.4 0 2.2 2.2 0 0 0 4.3 0M8 17v-4h4v4",
      "card" => "M2.5 5h15v10h-15zM2.5 8.5h15M5.5 12h3",
      "chat" => "M3 4.5h14v9H8l-4 3v-3H3z",
      "file" => "M5 2.5h6.5L15 6v11.5H5zM11.5 2.5V6H15",
      "search" => "M9 15a6 6 0 1 0 0-12 6 6 0 0 0 0 12zM13.5 13.5 17 17",
      "filter" => "M3 4h14l-5.5 6.5V16l-3 1.5v-7z",
      "plus" => "M10 4v12M4 10h12",
      "download" => "M10 3v10M6 9l4 4 4-4M4 17h12",
      "x" => "M5 5l10 10M15 5 5 15",
      "chevron-left" => "M12 5l-5 5 5 5",
      "chevron-right" => "M8 5l5 5-5 5",
      "chevron-up" => "M5 12.5l5-5 5 5",
      "chevron-down" => "M5 7.5l5 5 5-5",
      "sort" => "M7 8l3-3 3 3M7 12l3 3 3-3",
      "sun" => "M10 13.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM10 1.5v2M10 16.5v2M1.5 10h2M16.5 10h2M4 4l1.4 1.4M14.6 14.6 16 16M4 16l1.4-1.4M14.6 5.4 16 4",
      "moon" => "M16.5 12.5A7 7 0 0 1 7.5 3.5a7 7 0 1 0 9 9z",
      "menu" => "M3 5.5h14M3 10h14M3 14.5h14",
      "logout" => "M8 3.5H4v13h4M12.5 6.5 16 10l-3.5 3.5M16 10H8",
      "pencil" => "M13.5 3.5l3 3L7 16H4v-3z",
      "trash" => "M4 6h12M8 6V3.5h4V6M5.5 6l1 11h7l1-11",
      "grip" => "M7.5 5h.01M12.5 5h.01M7.5 10h.01M12.5 10h.01M7.5 15h.01M12.5 15h.01",
      "eye" => "M2 10s3-5.5 8-5.5S18 10 18 10s-3 5.5-8 5.5S2 10 2 10zM10 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z",
      "bolt" => "M11 2 4 11h5.5l-1 7 7-9.5H10z",
      "inbox" => "M3 11.5 5 4h10l2 7.5V16H3zM3 11.5h4.5l1 2h3l1-2H17"
    }.freeze

    def wibawa_icon(name, size: "size-5", class: nil)
      path = ICONS.fetch(name.to_s) { ICONS["table"] }
      stroke = name.to_s == "grip" ? "2.5" : "1.5"
      tag.svg(tag.path(d: path), viewBox: "0 0 20 20", fill: "none", stroke: "currentColor",
                                 "stroke-width": stroke, "stroke-linecap": "round", "stroke-linejoin": "round",
                                 "aria-hidden": "true", class: [size, "shrink-0", binding.local_variable_get(:class)].compact.join(" "))
    end

    # The Wibawa mark: kawung, four table cells around one point.
    def wibawa_mark(size: "size-5")
      tag.svg(tag.path(d: MARK_PATH), viewBox: "0 0 256 256", fill: "currentColor", "aria-hidden": "true", class: "#{size} shrink-0")
    end
    
    # @font-face for the bundled typeface. Inline so asset URLs work under both Propshaft and Sprockets.
    def wibawa_font_face
      faces = { "latin" => FONT_LATIN_RANGE, "latin-ext" => FONT_LATIN_EXT_RANGE }.map do |subset, range|
        %(@font-face{font-family:"Plus Jakarta Sans";font-style:normal;font-weight:200 800;font-display:swap;) +
          %(src:url("#{asset_path("wibawa/plus-jakarta-sans-#{subset}.woff2")}") format("woff2");unicode-range:#{range}})
      end
      tag.style(faces.join.html_safe, nonce: content_security_policy_nonce)
    end
    
    def wibawa_button_class(style = :secondary, extra = nil)
      [BUTTON_BASE, BUTTON_STYLES.fetch(style.to_sym), extra].compact.join(" ")
    end

    def wibawa_input_class(errors = false)
      errors ? "#{INPUT_CLASS} #{INPUT_ERROR_CLASS}" : INPUT_CLASS
    end

    def wibawa_component(key, default)
      Wibawa.config.component(key, default)
    end

    def wibawa_logout_path
      setting = Wibawa.config.logout_path
      setting.is_a?(Proc) ? instance_exec(&setting) : setting
    end
  end
end
