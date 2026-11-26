module Wibawa
  # The messages at the top of a page after an action ("Order created.").
  class FlashComponent < BaseComponent
    def initialize(flash:)
      @flash = flash
    end

    # [[type, text], ...]. Only text is shown: other gems keep flags and hashes in the flash.
    def messages = @flash.to_h.select { |_type, message| message.is_a?(String) && message.present? }.to_a
    def render? = messages.any?
    def alert?(type) = %w[alert error].include?(type.to_s)

    def tone_class(type)
      alert?(type) ? "bg-danger/10 text-danger ring-danger/30" : "bg-success/10 text-success ring-success/30"
    end
  end
end
