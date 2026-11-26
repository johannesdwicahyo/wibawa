module Wibawa
  # The page shown instead of one that does not exist or that the user may not open.
  class ErrorPageComponent < BaseComponent
    CODES = { not_found: 404, forbidden: 403 }.freeze

    # status: :not_found or :forbidden
    def initialize(status:)
      @status = status.to_sym
    end

    attr_reader :status

    def code = CODES.fetch(status)
    def title = t("wibawa.errors.#{status}_title")
    def body = t("wibawa.errors.#{status}_body")
    def back_label = t("wibawa.back_to_dashboard")
    def back_url = root_path
  end
end
