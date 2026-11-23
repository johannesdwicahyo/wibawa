module Wibawa
  # Small string helpers. Inside Rails these delegate to ActiveSupport;
  # the fallbacks only exist so the DSL can be unit-tested without Rails.
  module Util
    module_function

    def underscore(str)
      return str.underscore if str.respond_to?(:underscore)

      str.to_s.gsub("::", "/")
         .gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
         .gsub(/([a-z\d])([A-Z])/, '\1_\2')
         .tr("-", "_").downcase
    end

    def pluralize(str)
      return str.pluralize if str.respond_to?(:pluralize)

      s = str.to_s
      if s.end_with?("y") && !s.end_with?("ay", "ey", "oy", "uy") then "#{s[0..-2]}ies"
      elsif s.end_with?("s", "x", "z", "ch", "sh") then "#{s}es"
      else "#{s}s"
      end
    end

    def singularize(str)
      return str.singularize if str.respond_to?(:singularize)

      s = str.to_s
      if s.end_with?("ies") then "#{s[0..-4]}y"
      elsif s.end_with?("ses", "xes", "zes", "ches", "shes") then s[0..-3]
      elsif s.end_with?("s") then s[0..-2]
      else s
      end
    end

    def humanize(str)
      return str.to_s.humanize if str.to_s.respond_to?(:humanize)

      s = str.to_s.sub(/_id\z/, "").tr("_", " ").strip
      s.empty? ? s : s[0].upcase + s[1..]
    end

    def route_key(model_name)
      pluralize(underscore(model_name).tr("/", "_"))
    end
  end
end
