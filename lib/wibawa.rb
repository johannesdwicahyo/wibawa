require "wibawa/version"
require "wibawa/util"
require "wibawa/configuration"
require "wibawa/definitions"
require "wibawa/builders"
require "wibawa/resource"
require "wibawa/dashboard"
require "wibawa/report"
require "wibawa/page"
require "wibawa/registry"
require "wibawa/model_history"

module Wibawa
  class Error < StandardError; end
  class ResourceNotFound < Error; end
  class NotAuthorized < Error; end

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    def registry
      @registry ||= Registry.new
    end

    # Register a resource:
    #
    #   Wibawa.resource Order do
    #     scope :pending, -> { where(status: :pending) }
    #   end
    def resource(model, **options, &block)
      registry.register(Resource.new(model, **options, &block))
    end

    # Register a report (see Wibawa::Report):
    #
    #   Wibawa.report :sales_by_status do
    #     sql "SELECT status, COUNT(*) AS orders FROM orders GROUP BY status"
    #   end
    def report(name, &block)
      registry.register_report(Report.new(name, &block))
    end

    # Register a custom page (see Wibawa::Page):
    #
    #   Wibawa.page :maintenance do
    #     content { tag.p("Hello") }
    #   end
    def page(name, &block)
      registry.register_page(Page.new(name, &block))
    end

    # Define the dashboard shown at the admin root.
    def dashboard(&block)
      registry.dashboard = Dashboard.new(&block)
    end

    # (Re)load every resource file. Called on boot and on each code reload.
    def load!
      registry.clear!
      # Before the app's files, so an app can register its own "audit_log" resource instead.
      registry.register(Wibawa::AuditEntry.resource) if config.audit_log
      config.load_paths.each do |path|
        Dir[File.join(path.to_s, "**", "*.rb")].sort.each { |file| load file }
      end
      registry
    end
  end
end

if defined?(Rails::Engine)
  require "view_component"
  require "turbo-rails"
  require "wibawa/presenter"
  require "wibawa/query"
  require "wibawa/paginator"
  require "wibawa/csv_exporter"
  require "wibawa/csv_importer"
  require "wibawa/authorization"
  require "wibawa/engine"
end
