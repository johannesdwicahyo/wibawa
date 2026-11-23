module Wibawa
  class BaseComponent < ViewComponent::Base
    delegate :resources_path, :resource_path, :new_resource_path, :edit_resource_path,
             :batch_resources_path, :member_action_resource_path, :root_path,
             :wibawa_authorized?, :wibawa_presenter, :wibawa_icon, :wibawa_button_class,
             :wibawa_input_class, :wibawa_component, :class_names, :request, to: :helpers

    def presenter = wibawa_presenter

    def icon(name, **options) = wibawa_icon(name, **options)

    # Use the app's translations (wibawa.*) rather than component-relative keys.
    def t(key, **options) = helpers.t(key, **options)

    def card_class
      "rounded-xl bg-white ring-1 ring-zinc-950/[0.07] shadow-xs dark:bg-white/[0.03] dark:ring-white/10"
    end

    # Current index query string minus the given keys, for building links.
    def preserved_params(*except)
      request.query_parameters.except(*except.map(&:to_s))
    end
  end
end
