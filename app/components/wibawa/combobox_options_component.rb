module Wibawa
  # The matches a searchable select shows under its box, fetched as you type.
  # wibawa.js reads each option's data-value and text, so keep both.
  class ComboboxOptionsComponent < BaseComponent
    def initialize(options:)
      @options = options
    end

    attr_reader :options

    def label(record) = presenter.display_name(record)
    def empty_text = t("wibawa.combobox.empty")
  end
end
