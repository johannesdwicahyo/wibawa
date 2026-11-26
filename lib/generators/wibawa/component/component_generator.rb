require "rails/generators"

module Wibawa
  module Generators
    # Copy a built-in component into your app so you can change its markup:
    #   bin/rails g wibawa:component index_table
    # creates app/components/admin/index_table_component.rb (+ .html.erb, unless --no-template)
    # and prints the config line that switches Wibawa to it.
    class ComponentGenerator < Rails::Generators::Base
      argument :component, type: :string, desc: "e.g. index_table, sidebar, show_page, form_page, filters, dashboard"
      class_option :namespace, type: :string, default: "Admin"
      class_option :template, type: :boolean, default: true, desc: "Copy the template too. Leave it out (--no-template) to change methods only: the subclass then keeps using Wibawa's own template, updates included"

      source_root File.expand_path("../../../../app/components/wibawa", __dir__)

      def copy_component
        source_dir = self.class.source_root
        source_template = File.join(source_dir, "#{component}_component.html.erb")
        raise Thor::Error, "Unknown component: #{component}" unless File.exist?(File.join(source_dir, "#{component}_component.rb"))

        ns = options[:namespace]
        dir = File.join("app/components", ns.underscore)
        create_file File.join(dir, "#{component}_component.rb"), <<~RUBY
          module #{ns}
            class #{component.camelize}Component < Wibawa::#{component.camelize}Component
            end
          end
        RUBY
        copy_file "#{component}_component.html.erb", File.join(dir, "#{component}_component.html.erb") if options[:template] && File.exist?(source_template)

        say ""
        say "Add to config/initializers/wibawa.rb:", :green
        say %(  config.components[:#{component}] = "#{ns}::#{component.camelize}Component")
      end
    end
  end
end
