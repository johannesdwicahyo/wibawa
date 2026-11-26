module Wibawa
  # The bar across the top on phones and tablets, where the sidebar is tucked
  # away: the menu button, the admin's name, and the search button.
  # wibawa.js opens the menu and the palette from the buttons' data attributes.
  class TopbarComponent < BaseComponent
    def title = Wibawa.config.site_title
    def home_url = root_path
  end
end
