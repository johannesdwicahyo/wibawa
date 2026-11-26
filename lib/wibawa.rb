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

    # A column format of your own, for `column :rating, as: :stars` (index, show
    # page, dashboard tables and reports). The block runs in the view, so helpers
    # work, and gets the value, the record and the column. It is not called for nil.
    #
    #   Wibawa.column_type :stars do |value|
    #     tag.span("★" * value.to_i, role: "img", "aria-label": "#{value} of 5")
    #   end
    def column_type(name, &block)
      raise ArgumentError, "Wibawa.column_type :#{name} needs a block" unless block

      config.column_types[name.to_sym] = block
    end

    # A form input of your own, for `field :rating, as: :stars`. The block runs
    # in the view and returns the input; Wibawa adds the label, hint and errors.
    #
    #   Wibawa.field_type :stars do |form, attribute, html_options|
    #     form.select(attribute, (1..5).map { |n| [ "★" * n, n ] }, { include_blank: true }, html_options)
    #   end
    def field_type(name, &block)
      raise ArgumentError, "Wibawa.field_type :#{name} needs a block" unless block

      config.field_types[name.to_sym] = block
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
