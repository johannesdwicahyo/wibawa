module Wibawa
  # Model Context Protocol endpoint: the admin's resources as tools for AI agents.
  #
  # Off until `config.mcp_authenticate_with` is set. Each request carries a
  # bearer token, the block turns it into a user, and that user goes through
  # the same authorization, scopes and strong params as in the browser.
  #
  # That block is the only gate in front of this endpoint: `authenticate_with`
  # does not run here, so it must return admins only.
  #
  # It does not inherit from the app's parent controller: that one signs
  # people in with a session, which an agent does not have.
  #
  # ponytail: plain JSON over POST, one message per request. No sessions, no
  # SSE stream; add the gem's StreamableHTTPTransport if a tool ever needs to
  # push progress.
  class McpController < ActionController::Base
    include Wibawa::ResourceAccess

    skip_forgery_protection # token-authenticated, no cookies involved

    helper Wibawa::ApplicationHelper
    helper_method :wibawa_current_user, :wibawa_authorized?, :wibawa_presenter

    attr_reader :resource, :wibawa_current_user

    ToolError = Class.new(StandardError)

    MAX_BATCH = 1000

    RESOURCE = { resource: { type: "string", description: "Resource key from list_resources, e.g. \"orders\"" } }.freeze
    ID = { id: { type: %w[string integer], description: "Record id" } }.freeze
    ATTRIBUTES = { attributes: { type: "object", description: "Attribute values. Only the resource's writable_attributes are accepted; others are ignored." } }.freeze

    TOOLS = {
      list_resources: {
        description: "List the admin resources you may read, with their columns, scopes, filters and actions. Call this first.",
        properties: {}
      },
      list_records: {
        description: "List records of a resource, one page at a time. Supports the resource's scopes, search, filters and sortable columns.",
        properties: RESOURCE.merge(
          scope: { type: "string", description: "One of the resource's scopes" },
          search: { type: "string", description: "Free-text search, if the resource is searchable" },
          filters: { type: "object", description: "Filter name => value. Range filters take <name>_from and <name>_to." },
          sort: { type: "string", description: "Column to sort by" },
          direction: { type: "string", enum: %w[asc desc] },
          page: { type: "integer", minimum: 1 },
          per_page: { type: "integer", minimum: 1 }
        ),
        required: %w[resource]
      },
      get_record: { description: "Show one record with all its detail fields.", properties: RESOURCE.merge(ID), required: %w[resource id] },
      list_reports: {
        description: "List the reports you may run (aggregates and summaries the admin's owner has defined), with the parameters each accepts.",
        properties: {}
      },
      run_report: {
        description: "Run a report and get its rows. Prefer this over paging through records when a report answers the question.",
        properties: {
          report: { type: "string", description: "Report key from list_reports" },
          params: { type: "object", description: "Parameter name => value. Dates as YYYY-MM-DD. Omitted parameters use their defaults." },
          page: { type: "integer", minimum: 1, description: "1,000 rows per page. Ask for the next page when has_next is true." }
        },
        required: %w[report]
      },
      create_record: { description: "Create a record.", properties: RESOURCE.merge(ATTRIBUTES), required: %w[resource attributes], write: true },
      update_record: { description: "Update a record.", properties: RESOURCE.merge(ID, ATTRIBUTES), required: %w[resource id attributes], write: true },
      delete_record: { description: "Delete a record. This cannot be undone.", properties: RESOURCE.merge(ID), required: %w[resource id], write: true, destructive: true },
      run_action: {
        description: "Run one of the resource's actions (see list_resources) on a record.",
        properties: RESOURCE.merge(ID, action: { type: "string", description: "Action name" }),
        required: %w[resource id action], write: true, destructive: true
      },
      run_batch_action: {
        description: "Run one of the resource's batch actions (see list_resources) on several records at once. Ids you may not see are skipped; `matched` says how many records it ran on.",
        properties: RESOURCE.merge(
          action: { type: "string", description: "Batch action name" },
          ids: { type: "array", items: { type: %w[string integer] }, minItems: 1, maxItems: MAX_BATCH, description: "Record ids, at most #{MAX_BATCH} per call" }
        ),
        required: %w[resource action ids], write: true, destructive: true
      }
    }.freeze

    def handle
      authenticate = Wibawa.config.mcp_authenticate
      return head :not_found unless authenticate
      return head :method_not_allowed, allow: "POST" unless request.post?

      token = request.authorization.to_s[/\ABearer (.+)\z/, 1]
      @wibawa_current_user, granted = token && instance_exec(token, &authenticate)
      @scopes = Wibawa::McpScopes.new(granted)
      return challenge(:unauthorized, scope: Wibawa::McpScopes.baseline) unless wibawa_current_user

      # One message per request: a batch could mix resources, and each resource
      # installs its own `controller do` overrides on this controller instance.
      body = request.raw_post
      return head :bad_request if body.lstrip.start_with?("[")

      # A tool the token's scopes do not cover is refused here, as HTTP 403 naming
      # the scope to ask for, which is what lets a client go and get it.
      needed = scope_needed_for(body)
      return challenge(:forbidden, scope: needed, error: "insufficient_scope") if needed

      reply = server.handle_json(body)
      reply ? render(json: reply) : head(:accepted)
    end

    # OAuth Protected Resource Metadata: where a client learns which
    # authorization servers issue tokens for this endpoint.
    def resource_metadata
      return head :not_found unless Wibawa.config.mcp_authenticate && oauth?

      render json: { resource: mcp_resource, authorization_servers: Wibawa.config.mcp_authorization_servers,
                     scopes_supported: [ Wibawa::McpScopes.baseline ], bearer_methods_supported: %w[header],
                     resource_name: Wibawa.config.site_title }
    end

    private

    def server
      begin
        require "mcp"
      rescue LoadError
        raise Wibawa::Error, 'The Wibawa MCP server needs the mcp gem. Add `gem "mcp"` to your Gemfile.'
      end

      controller = self
      tools = TOOLS.filter_map do |name, spec|
        next if spec[:write] && !(Wibawa.config.mcp_write && @scopes.allow?(write: true))

        MCP::Tool.define(
          name: name.to_s, description: spec[:description],
          input_schema: { properties: spec[:properties], required: spec[:required] }.compact,
          annotations: { read_only_hint: !spec[:write], destructive_hint: !!spec[:destructive], open_world_hint: false }
        ) { |server_context: nil, **args| controller.send(:call_tool, name, args) }
      end

      MCP::Server.new(name: "wibawa", version: Wibawa::VERSION, tools: tools, capabilities: { tools: {} },
                      instructions: "Admin data for #{Wibawa.config.site_title}. Call list_resources first to see what exists.")
    end

    def oauth? = Wibawa.config.mcp_authorization_servers.present?

    # This endpoint's canonical URL: what a token must have been issued for.
    # In mcp_authenticate_with, compare the token's audience with it.
    def mcp_resource
      (Wibawa.config.mcp_resource.presence || "#{request.base_url}#{request.script_name}/mcp").to_s.chomp("/")
    end
    public :mcp_resource

    # 401 or 403 with the Bearer challenge of RFC 6750. With OAuth configured it
    # also says where the metadata is and which scope would be enough.
    def challenge(status, scope:, error: nil)
      parts = []
      parts << %(error="#{error}") if error
      if oauth? || error
        parts << %(scope="#{scope}")
        parts << %(resource_metadata="#{mcp_resource}/oauth-protected-resource") if oauth?
      end
      response.headers["WWW-Authenticate"] = [ "Bearer", parts.join(", ").presence ].compact.join(" ")
      head status
    end

    # The scope a tools/call needs and the token lacks, or nil when it may go ahead.
    def scope_needed_for(body)
      return nil if @scopes.unrestricted?

      message = JSON.parse(body)
      return nil unless message.is_a?(Hash) && message["method"] == "tools/call"

      spec = TOOLS[message.dig("params", "name").to_s.to_sym] or return nil
      arguments = message.dig("params", "arguments")
      key = arguments.is_a?(Hash) ? (arguments["resource"] || arguments["report"]).presence : nil
      @scopes.needed(key, write: !!spec[:write]) unless @scopes.allow?(key, write: !!spec[:write])
    rescue JSON::ParserError
      nil # the protocol layer answers a malformed message
    end

    def call_tool(name, args)
      @tool_params = ActionController::Parameters.new(
        args.except(:filters, :attributes).merge(q: args[:filters], record: args[:attributes]).compact
      )
      use_resource(args[:resource]) if args[:resource]
      MCP::Tool::Response.new([ { type: "text", text: send(:"tool_#{name}").to_json } ])
    rescue Wibawa::ResourceNotFound, ActiveRecord::RecordNotFound
      failure("Not found.")
    rescue Wibawa::NotAuthorized
      failure("Not authorized.")
    rescue ToolError => e
      failure(e.message)
    end

    def failure(message) = MCP::Tool::Response.new([ { type: "text", text: message } ], error: true)

    # The shared hooks (find_record, record_params, per_page, Query) read `params`.
    def params = @tool_params || super

    # ---- Tools -------------------------------------------------------------

    def tool_list_resources
      Wibawa.registry.select { |r| r.action?(:index) && @scopes.allow?(r.key) && wibawa_authorized?(:index, r.model) }.map do |r|
        info = {
          resource: r.key, label: r.label, columns: r.index_columns.map(&:name), scopes: r.scopes.map(&:name),
          searchable: r.search_fields.present?,
          filters: r.filters.to_h { |f| [ f.name, Wibawa::Query.filter_type(r.model, f) ] }
        }
        if Wibawa.config.mcp_write
          next info unless @scopes.allow?(r.key, write: true)

        info.merge!(actions: r.member_actions.map(&:name), writable_attributes: r.permitted_attributes,
                      batch_actions: r.batch_actions.select { |a| wibawa_authorized?(:"batch_#{a.name}", r.model) }.map(&:name))
        end
        info
      end
    end

    def tool_list_records
      ensure_action!(:index)
      wibawa_authorize!(:index, model)
      query = Wibawa::Query.new(resource, authorized_collection, params, related: wibawa_related)
      page = Wibawa::Paginator.new(query.relation, page: params[:page], per_page: per_page, count: resource.index_options[:count])
      wibawa_presenter.prime_related(page.records.to_a, resource.index_columns)
      records = page.records.map { |record| serialize(record, resource.index_columns) }
      log_read(:list, resource, nil, params.permit(:scope, :search, :sort, :direction, :page, q: {}).to_h.merge(returned: records.size))
      { records: records,
        page: page.page, per_page: page.per_page, total: page.total_count, has_next: page.next? }
    end

    def tool_get_record
      ensure_action!(:show)
      record = find_record
      wibawa_authorize!(:show, record)
      log_read(:show, resource, record)
      detail(record)
    end

    def tool_list_reports
      Wibawa.registry.reports.select { |report| @scopes.allow?(report.key) && wibawa_authorized?(:show, report) }.map do |report|
        { report: report.key, title: report.title, description: report.description,
          params: report.params.map { |param| { name: param.name, type: param.as, default: json_value(param.default), options: param.collection }.compact } }.compact
      end
    end

    def tool_run_report
      report = Wibawa.registry.report(params[:report]) || raise(Wibawa::ResourceNotFound)
      wibawa_authorize!(:show, report)
      values = report.values(params[:params])
      page = Wibawa::ReportPaginator.new(report.result(values), page: params[:page], per_page: Wibawa::Report::MAX_ROWS)
      rows = page.records.map { |row| row.transform_values { |value| json_value(value) } }
      log_read(:run_report, report, nil, values.transform_values { |value| json_value(value) }.merge(page: page.page, returned: rows.size))
      { report: report.key, params: values.transform_values { |value| json_value(value) },
        rows: rows,
        page: page.page, total: page.total_count, has_next: page.next? }
    end

    def tool_create_record
      ensure_action!(:create)
      record = build_record
      rejected = wibawa_assign(record, record_params)
      wibawa_authorize!(:create, record)
      save(record, rejected)
    end

    def tool_update_record
      ensure_action!(:update)
      record = find_record
      wibawa_authorize!(:update, record)
      save(record, wibawa_assign(record, record_params))
    end

    def tool_delete_record
      ensure_action!(:destroy)
      record = find_record
      wibawa_authorize!(:destroy, record)
      record.destroy || raise(ToolError, record.errors.full_messages.to_sentence.presence || "Could not delete.")
      wibawa_audit(:destroy, record)
      { deleted: record.id }
    end

    def tool_run_action
      action = resource.find_member_action(params[:action]) || raise(Wibawa::ResourceNotFound)
      record = find_record
      wibawa_authorize!(action.name, record)
      result = instance_exec(record, &action.block)
      wibawa_audit(action.name, record)
      discard_browser_response
      { message: result.is_a?(String) ? result : "#{action.label} done.", record: detail(record) }
    end

    def tool_run_batch_action
      ids = Array(params[:ids]).compact_blank
      raise ToolError, "Give between 1 and #{MAX_BATCH} ids." unless ids.size.between?(1, MAX_BATCH)

      action, result, matched = run_batch_action(params[:action], ids)
      discard_browser_response
      { message: result.is_a?(String) ? result : "#{action.label} done.", matched: matched }
    end

    # An action written for the browser may redirect or render; the agent gets JSON instead.
    def discard_browser_response
      return unless performed?

      self.response_body = nil
      self.status = 200
      response.headers.delete("Location")
    end

    # What an agent read goes in the audit log too, when that is on: which
    # records or report, with what search and filters, and how many rows came back.
    def log_read(action, subject, record = nil, data = nil)
      return unless Wibawa.config.audit_log

      Wibawa::AuditEntry.record!(user: wibawa_current_user, action: action, resource: subject, record: record, data: data, via: "mcp")
    end

    # ---- Serialization -----------------------------------------------------

    def save(record, rejected)
      action = record.new_record? ? :create : :update
      wibawa_save(record, rejected) || raise(ToolError, record.errors.full_messages.to_sentence)
      wibawa_audit(action, record, record.saved_changes)
      detail(record)
    end

    def detail(record)
      serialize(record, resource.show_items.filter_map { |kind, column| column if kind == :row })
    end

    # Only the columns the resource declares, as in the browser.
    def serialize(record, columns)
      { id: record.id }.merge(columns.to_h { |column| [ column.name, json_value(wibawa_presenter.raw(record, column)) ] })
    end

    def json_value(value)
      case value
      when ActiveSupport::SafeBuffer then helpers.strip_tags(value).squish
      when nil, true, false, Numeric, String, Hash then value
      when ActiveRecord::Base then { id: value.id, name: wibawa_presenter.related_name(value) }
      when ActiveRecord::Relation then wibawa_presenter.related_records(value).first(100).map { |item| json_value(item) }
      when Array then value.first(100).map { |item| json_value(item) }
      when Time, Date then value.iso8601
      else value.respond_to?(:to_plain_text) ? value.to_plain_text : value.to_s
      end
    end
  end
end
