module Wibawa
  class Configuration
    # Shown in the sidebar and the <title>.
    attr_accessor :site_title

    # Wibawa's controllers inherit from this class, so your authentication
    # concerns (Rails 8 `Authentication`, Devise helpers, ...) apply.
    attr_accessor :parent_controller

    # Symbol (method on the controller) or proc (run in the controller) that
    # returns the signed-in user. Used for authorization and the header.
    attr_accessor :current_user

    # nil (allow everything), :pundit, :action_policy, a proc
    # `->(user, action, subject) { ... }`, or an adapter class.
    attr_accessor :authorization

    # Directories holding resource files. Defaults to app/wibawa. To change it,
    # set Wibawa.config.load_paths in config/application.rb so it applies
    # before autoloading is set up.
    attr_accessor :load_paths

    attr_accessor :per_page, :per_page_options, :max_per_page

    # Show record counts next to scopes. Turn off for very large tables.
    attr_accessor :scope_counts

    # ISO code used by `as: :money` columns. Override per column with `currency:`.
    attr_accessor :currency

    # Optional proc `->(value, currency, view) { ... }` for money formatting.
    attr_accessor :money_format

    # status value => :success / :warning / :danger / :info / :neutral
    attr_accessor :badge_colors

    # Methods tried, in order, to label a record in links and titles.
    attr_accessor :display_name_methods

    # Path (string or proc run in the view) for the sign-out link, and its HTTP method.
    attr_accessor :logout_path, :logout_method

    # Any CSS color. Sets the --wb-primary variable used for buttons and links.
    attr_accessor :brand_color

    # :bundled serves Plus Jakarta Sans from the gem (no third-party request);
    # :system uses the operating system's UI font.
    attr_accessor :font

    # Lets the MCP server create, update and delete records and run member
    # actions. Off by default: agents can only read.
    attr_accessor :mcp_write

    # Lets each user save an index page's scope, search, filters and sort under
    # a name. Needs a table: run `bin/rails g wibawa:saved_views` first.
    attr_accessor :saved_views

    # Records every create, update, delete and action made through the admin
    # (browser and MCP). Needs a table: run `bin/rails g wibawa:audit_log` first.
    attr_accessor :audit_log

    # Swap any built-in component for your own subclass:
    #   config.components[:index_table] = "Admin::IndexTableComponent"
    attr_accessor :components

    def initialize
      @site_title = "Admin"
      @parent_controller = "ActionController::Base"
      @current_user = :current_user
      @authorization = nil
      @authenticate = nil
      @load_paths = []
      @per_page = 50
      @per_page_options = [25, 50, 100, 250, 500]
      @max_per_page = 500
      @scope_counts = true
      @currency = "USD"
      @money_format = nil
      @badge_colors = {
        success: %w[active approved completed complete delivered done paid published success succeeded verified],
        warning: %w[draft pending processing queued review scheduled unpaid waiting],
        danger: %w[blocked canceled cancelled declined error expired failed rejected refunded suspended],
        info: %w[new open sent shipped]
      }
      @display_name_methods = %i[display_name full_name name title email username code number]
      @logout_path = nil
      @logout_method = :delete
      @brand_color = nil
      @font = :bundled
      @components = {}
      @mcp_write = false
      @saved_views = false
      @audit_log = false
      @mcp_authenticate = nil
    end

    # Runs as a before_action inside Wibawa's controllers:
    #   config.authenticate_with { redirect_to main_app.root_path unless Current.user&.admin? }
    #
    # Outside development and test, Wibawa refuses every request until this is
    # set, so a forgotten initializer cannot publish the admin. If something
    # else already guards it, say which instead of giving a block:
    #   config.authenticate_with :parent_controller  # a before_action in parent_controller
    #   config.authenticate_with :none               # the network does (VPN, basic auth in the proxy)
    def authenticate_with(elsewhere = nil, &block)
      unless block || %i[parent_controller none].include?(elsewhere)
        raise ArgumentError, "authenticate_with takes a block, :parent_controller or :none"
      end

      @authenticate = block || elsewhere
    end

    def authenticate
      @authenticate
    end

    # Turns on the MCP server at <mount path>/mcp. The block gets the bearer
    # token an agent sent and returns the user it belongs to, or nil:
    #   config.mcp_authenticate_with { |token| ApiToken.find_by(digest: Digest::SHA256.hexdigest(token))&.user&.then { |user| user if user.admin? } }
    # This block is the admin gate for agents: `authenticate_with` does not run
    # on the MCP endpoint, so return only users who may use the admin. That
    # user then goes through the same authorization as in the browser.
    def mcp_authenticate_with(&block)
      @mcp_authenticate = block
    end
    
    def mcp_authenticate
      @mcp_authenticate
    end

    # Shorthand: config.authorize_with { |user, action, subject| user.admin? }
    def authorize_with(adapter = nil, &block)
      @authorization = block || adapter
    end

    def component(key, default)
      klass = components[key.to_sym] || default
      klass.is_a?(String) ? Object.const_get(klass) : klass
    end

    def badge_color_for(value)
      v = value.to_s.downcase
      badge_colors.each { |color, values| return color if Array(values).map(&:to_s).include?(v) }
      :neutral
    end
  end
end
