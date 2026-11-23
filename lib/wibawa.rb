require "wibawa/version"
require "wibawa/util"
require "wibawa/configuration"
require "wibawa/definitions"
require "wibawa/builders"
require "wibawa/resource"
require "wibawa/dashboard"
require "wibawa/registry"

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

    # Define the dashboard shown at the admin root.
    def dashboard(&block)
      registry.dashboard = Dashboard.new(&block)
    end

    # (Re)load every resource file. Called on boot and on each code reload.
    def load!
      registry.clear!
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
  require "wibawa/authorization"
  require "wibawa/engine"
end
