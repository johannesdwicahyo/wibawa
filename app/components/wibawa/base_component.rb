module Wibawa
  class BaseComponent < ViewComponent::Base
    delegate :resources_path, :resource_path, :new_resource_path, :edit_resource_path,
             :batch_resources_path, :options_resource_path, :member_action_resource_path, :root_path,
             :wibawa_authorized?, :wibawa_presenter, :wibawa_icon, :wibawa_button_class,
             :wibawa_input_class, :wibawa_component, :class_names, :request, to: :helpers

    def presenter = wibawa_presenter

    def icon(name, **options) = wibawa_icon(name, **options)

    # Use the app's translations (wibawa.*) rather than component-relative keys.
    def t(key, **options) = helpers.t(key, **options)

    # Records of another model the current user may see: what a select may list
    # and what a chosen id may be named as.
    def authorized_scope(klass)
      Wibawa::Authorization.build(helpers.wibawa_current_user).scope(klass.all)
    end

    def card_class
      "rounded-card bg-surface ring-1 ring-line"
    end

    # Current index query string minus the given keys, for building links.
    def preserved_params(*except)
      request.query_parameters.except(*except.map(&:to_s))
    end
  end
end
