module Wibawa
  class Engine < ::Rails::Engine
    isolate_namespace Wibawa

    initializer "wibawa.load_paths", before: :set_autoload_paths do |app|
      default = app.root.join("app", "wibawa")
      Wibawa.config.load_paths = [ default ] if Wibawa.config.load_paths.empty?

      # Resource files call Wibawa.resource; they don't define constants,
      # so Zeitwerk must not try to autoload them.
      Wibawa.config.load_paths.each do |path|
        Rails.autoloaders.main.ignore(path.to_s)
      end
    end

    initializer "wibawa.reloading" do |app|
      # Editing a resource file triggers a reload in development.
      Wibawa.config.load_paths.each do |path|
        app.config.watchable_dirs[path.to_s] = [ "rb" ]
      end
    end

    initializer "wibawa.assets" do |app|
      if app.config.respond_to?(:assets)
        %w[builds javascripts fonts].each do |dir|
          path = root.join("app", "assets", dir).to_s
          app.config.assets.paths << path unless app.config.assets.paths.include?(path)
        end
        app.config.assets.precompile += %w[wibawa.css wibawa.js wibawa/plus-jakarta-sans-latin.woff2 wibawa/plus-jakarta-sans-latin-ext.woff2] if app.config.assets.respond_to?(:precompile)
      end
    end

    initializer "wibawa.i18n" do |app|
      app.config.i18n.load_path += Dir[root.join("config", "locales", "*.yml")]
    end

    config.to_prepare do
      Wibawa.load!
    end
  end
end
