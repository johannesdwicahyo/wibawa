module Wibawa
  # Authorization and the per-resource hooks. Shared by the HTML controllers
  # and the MCP endpoint, so both see exactly the same records.
  module ResourceAccess
    private

    def wibawa_authorizer
      @wibawa_authorizer ||= Wibawa::Authorization.build(wibawa_current_user)
    end

    def wibawa_authorized?(action, subject)
      wibawa_authorizer.authorized?(action, subject)
    end

    def wibawa_authorize!(action, subject)
      raise Wibawa::NotAuthorized unless wibawa_authorized?(action, subject)
    end

    def wibawa_presenter
      @wibawa_presenter ||= Wibawa::Presenter.new(view_context)
    end

    # Selects the resource for this request and applies its `controller do ... end` overrides.
    def use_resource(key)
      @resource = Wibawa.registry.fetch(key)
      resource.controller_blocks.each { |block| singleton_class.class_eval(&block) }
    end

    def model = resource.model

    def ensure_action!(action)
      raise Wibawa::ResourceNotFound unless resource.action?(action)
    end

    # ---- Hooks: override per resource with `controller do ... end` ---------

    # Base relation for index, batch and record lookup.
    def scoped_collection
      model.all
    end

    def authorized_collection
      wibawa_authorizer.scope(scoped_collection)
    end

    def find_record
      authorized_collection.find(params[:id])
    end

    def build_record
      scoped_collection.new
    end

    def record_params
      params.fetch(:record, {}).permit(*resource.permitted_attributes)
    end

    def per_page
      requested = params[:per_page].to_i
      default = resource.index_options[:per_page] || Wibawa.config.per_page
      requested.positive? ? [requested, Wibawa.config.max_per_page].min : default
    end
  end
end
