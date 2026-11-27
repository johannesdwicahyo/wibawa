module Wibawa
  # What one MCP access token may do, as OAuth scopes.
  #
  #   wibawa:read            read every resource and report
  #   wibawa:read:orders     read the orders resource only (a resource key or a report key)
  #   wibawa:write           read and change every resource
  #   wibawa:write:orders    read and change orders only
  #
  # Write implies read, and a scope without a key covers every key. A token
  # with no scope information at all (the app's block returned only a user) is
  # unrestricted: that is how static tokens worked before scopes existed.
  class McpScopes
    LEVELS = %w[read write].freeze

    attr_reader :prefix

    # granted: nil for an unrestricted token, or the token's scopes as an array
    # or an OAuth space-separated string. Scopes with another prefix are ignored.
    def initialize(granted, prefix: Wibawa.config.mcp_scope_prefix)
      @prefix = prefix.to_s
      @unrestricted = granted.nil?
      names = granted.is_a?(String) ? granted.split : Array(granted).map(&:to_s)
      @granted = names.filter_map { |name| parse(name) }
    end

    def unrestricted? = @unrestricted

    # Whether the token may read (or, with write: true, change) `key`. Without
    # a key: whether it may do so for anything at all.
    def allow?(key = nil, write: false)
      return true if unrestricted?

      @granted.any? do |level, granted_key|
        (level == "write" || !write) && (key.nil? || granted_key.nil? || granted_key == key.to_s)
      end
    end

    # The narrowest scope that would allow it: what a refused request is told to ask for.
    def needed(key = nil, write: false)
      [ prefix, write ? "write" : "read", key ].compact.join(":")
    end

    # The baseline a client is told to ask for before it knows what it will do.
    def self.baseline = "#{Wibawa.config.mcp_scope_prefix}:read"

    private

    def parse(name)
      scope_prefix, level, key = name.split(":", 3)
      # A scope that ends in a colon is malformed, and grants nothing: read as "no key" it would grant everything.
      [ level, key ] if scope_prefix == prefix && LEVELS.include?(level) && key != ""
    end
  end
end
