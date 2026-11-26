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

    # Writes an audit entry when config.audit_log is on. `data` is the record's
    # saved_changes, or whatever describes the action.
    def wibawa_audit(action, record = nil, data = nil)
      return unless Wibawa.config.audit_log

      Wibawa::AuditEntry.record!(user: wibawa_current_user, action: action, resource: resource, record: record, data: data,
                                 via: is_a?(Wibawa::McpController) ? "mcp" : "web")
    end

    # Runs a batch action on the records among `ids` this user may see, and
    # returns [what the action's block returned, how many records that was].
    def run_batch_action(name, ids)
      action = resource.find_batch_action(name) || raise(Wibawa::ResourceNotFound)
      wibawa_authorize!(:"batch_#{action.name}", model)

      records = authorized_collection.where(model.primary_key => ids)
      matched = records.count
      result = action.block ? instance_exec(records, &action.block) : batch_destroy(records)
      wibawa_audit(:"batch_#{action.name}", nil, { ids: ids.first(Wibawa::AuditEntry::MAX_IDS), count: ids.size })
      [ action, result, matched ]
    end

    def batch_destroy(records)
      destroyed = 0
      records.find_each { |r| destroyed += 1 if r.destroy }
      t("wibawa.flash.batch_destroyed", count: destroyed)
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

    # Sends an Enumerator of CSV lines as a download, without buffering it.
    def stream_csv_lines(filename, lines)
      response.headers["Content-Type"] = "text/csv; charset=utf-8"
      response.headers["Content-Disposition"] =
        ActionDispatch::Http::ContentDisposition.format(disposition: "attachment", filename: filename)
      response.headers["Cache-Control"] = "no-cache"
      response.headers["X-Accel-Buffering"] = "no"
      response.headers["Last-Modified"] = Time.now.httpdate # stops Rack::ETag from buffering the stream
      response.headers.delete("Content-Length")
      self.response_body = lines
    end

    def per_page
      requested = params[:per_page].to_i
      default = resource.index_options[:per_page] || Wibawa.config.per_page
      requested.positive? ? [ requested, Wibawa.config.max_per_page ].min : default
    end
  end
end
