module Wibawa
  # Turns index params (scope, search, filters, sort) into a relation.
  # Only filters and sort columns declared in the resource are applied.
  class Query
    STRING_TYPES = %i[string text citext].freeze
    NUMBER_TYPES = %i[integer bigint decimal float].freeze
    DATE_TYPES = %i[date datetime timestamp timestamptz].freeze

    attr_reader :resource, :params

    # related: a Wibawa::RelatedScope. With it, a filter that reaches through
    # an association only matches associated records the user may see.
    def initialize(resource, relation, params, related: nil)
      @resource = resource
      @base = relation
      @params = params
      @related = related
    end

    def model = resource.model

    CHOICE_MACROS = %i[belongs_to has_many has_and_belongs_to_many].freeze

    # What a filter name points at: [Order, "status"] for :status, and
    # [LineItem, "product"] for "line_items.product".
    def self.target(model, name)
      association, column = name.to_s.split(".", 2)
      return [ model, association ] unless column

      ref = model.reflect_on_association(association.to_sym)
      raise Error, "#{model} has no association :#{association} (used in filter #{name.inspect})" unless ref

      [ ref.klass, column ]
    end

    # Infer a filter's input type from the model when `as:` is omitted.
    def self.filter_type(model, filter)
      return filter.as.to_sym if filter.as
      return :search if filter.options[:on]

      klass, column = target(model, filter.name)
      ref = klass.reflect_on_association(column.to_sym)
      return :select if ref && !ref.polymorphic? && CHOICE_MACROS.include?(ref.macro)
      return :select if klass.defined_enums.key?(column)

      case klass.columns_hash[column]&.type
      when *NUMBER_TYPES then :number_range
      when *DATE_TYPES then :date_range
      when :boolean then :boolean
      else :string
      end
    end

    def current_scope
      @current_scope ||= begin
        requested = params[:scope].presence && resource.find_scope(params[:scope])
        requested || resource.default_scope
      end
    end

    def relation
      @relation ||= begin
        rel = current_scope ? current_scope.apply(filtered_base) : filtered_base
        includes = resource.index_includes
        rel = rel.includes(*includes) unless includes.empty?
        apply_sort(rel)
      end
    end

    # Search + filters, without the scope, so each scope tab can show a count.
    def filtered_base
      @filtered_base ||= apply_filters(apply_search(@base))
    end

    def scope_count(scope)
      scope.apply(filtered_base).count(:all)
    end

    def filter_values
      @filter_values ||= begin
        q = params[:q]
        q = q.to_unsafe_h if q.respond_to?(:to_unsafe_h)
        (q || {}).to_h.transform_keys(&:to_s)
      end
    end

    def filter_value(key) = filter_values[key.to_s]

    def search_term = params[:search].to_s.strip.presence

    def filtered?
      search_term.present? || filter_values.values.any? { |v| Array(v).any?(&:present?) }
    end

    def sort_key = params[:sort].presence
    def sort_direction = params[:direction] == "asc" ? :asc : :desc

    private

    # ---- search ------------------------------------------------------------

    def apply_search(rel)
      term = search_term
      fields = resource.search_fields
      return rel if term.nil? || fields.blank?

      search_across(rel, fields, term)
    end

    def search_across(rel, fields, term)
      joins = []
      conditions = fields.filter_map do |field|
        table, klass, column = resolve_field(field.to_s, joins)
        condition_for(table, klass, column, term)
      end
      return rel.none if conditions.empty?

      rel = rel.left_joins(*joins.uniq) unless joins.empty?
      rel.where(conditions.reduce { |a, b| a.or(b) })
    end

    # "customer.name" => [customers arel table, Customer, "name"], records the join.
    def resolve_field(field, joins)
      assoc, column = field.split(".", 2)
      return [ model.arel_table, model, assoc ] unless column

      ref = model.reflect_on_association(assoc.to_sym)
      raise Error, "#{model} has no association :#{assoc} (used in search/filter)" unless ref

      joins << assoc.to_sym
      [ ref.klass.arel_table, ref.klass, column ]
    end

    def condition_for(table, klass, column, term)
      type = klass.columns_hash[column]&.type
      attribute = table[column]
      if NUMBER_TYPES.include?(type)
        term.match?(/\A-?\d+(\.\d+)?\z/) ? attribute.eq(term) : nil
      elsif type.nil? || STRING_TYPES.include?(type)
        attribute.matches("%#{ActiveRecord::Base.sanitize_sql_like(term)}%", "\\", false)
      else
        attribute.eq(term)
      end
    end

    # ---- filters -----------------------------------------------------------

    def apply_filters(rel)
      resource.filters.reduce(rel) { |r, filter| apply_filter(r, filter) }
    end

    def apply_filter(rel, filter)
      name = filter.name.to_s
      if (custom = filter.options[:apply])
        value = filter_value(name)
        return Array(value).any?(&:present?) ? rel.instance_exec(value, &custom) : rel
      end

      type = self.class.filter_type(model, filter)
      return apply_search_filter(rel, filter) if type == :search

      klass, column = self.class.target(model, name)
      return apply_typed(rel, klass, column, name, type) unless name.include?(".")
      return rel unless filter_active?(name)

      # "line_items.product": the condition is on the associated table. A
      # subquery keeps one row per record however many associated rows match.
      matching = model.joins(name.split(".").first.to_sym).merge(apply_typed(visible(klass), klass, column, name, type))
      rel.where(model.primary_key => matching.select(model.arel_table[model.primary_key]))
    end

    # Every record of the associated model, or only those the user may see.
    def visible(klass) = @related ? @related.scope(klass.all) : klass.all

    def filter_active?(key)
      [ "", "_from", "_to" ].any? { |suffix| Array(filter_value("#{key}#{suffix}")).any?(&:present?) }
    end

    # `rel` is a relation on `klass`; `key` is the name the value was submitted under.
    def apply_typed(rel, klass, column, key, type)
      case type
      when :select then apply_select(rel, klass, column, key)
      when :boolean then apply_boolean(rel, column, key)
      when :date_range then apply_range(rel, klass, column, key, :date)
      when :number_range then apply_range(rel, klass, column, key, :number)
      else apply_string(rel, klass, column, key)
      end
    end

    def apply_search_filter(rel, filter)
      term = filter_value(filter.name).to_s.strip
      return rel if term.empty?

      search_across(rel, Array(filter.options[:on]).map(&:to_s), term)
    end

    def apply_select(rel, klass, column, key)
      values = Array(filter_value(key)).compact_blank
      return rel if values.empty?

      ref = klass.reflect_on_association(column.to_sym)
      case ref&.macro
      when :belongs_to
        rel.where(ref.foreign_key => values)
      when :has_many, :has_and_belongs_to_many
        # Records that have at least one of the chosen associated records.
        having = klass.joins(column.to_sym).merge(visible(ref.klass)).where(ref.klass.arel_table[ref.klass.primary_key].in(values))
        rel.where(klass.primary_key => having.select(klass.arel_table[klass.primary_key]))
      else
        rel.where(column => values)
      end
    end

    def apply_boolean(rel, column, key)
      value = filter_value(key)
      return rel if value.blank?

      rel.where(column => ActiveModel::Type::Boolean.new.cast(value))
    end

    def apply_string(rel, klass, column, key)
      term = filter_value(key).to_s.strip
      return rel if term.empty?

      rel.where(klass.arel_table[column].matches("%#{ActiveRecord::Base.sanitize_sql_like(term)}%", "\\", false))
    end

    def apply_range(rel, klass, column, key, kind)
      from = parse(filter_value("#{key}_from"), kind)
      to = parse(filter_value("#{key}_to"), kind)
      return rel if from.nil? && to.nil?

      if kind == :date && klass.columns_hash[column]&.type != :date
        from = from&.beginning_of_day
        to = to&.end_of_day
      end
      rel.where(column => from..to)
    end

    def parse(value, kind)
      return nil if value.blank?

      kind == :date ? Date.parse(value.to_s) : BigDecimal(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    # ---- sort --------------------------------------------------------------

    def apply_sort(rel)
      column = sort_key && resource.index_columns.find { |c| c.name.to_s == sort_key }
      expression = column&.sort_expression(model)

      if expression
        rel = sort_by_expression(rel, column, expression)
      elsif (default = resource.index_options[:sort])
        rel = rel.reorder(default)
      elsif rel.order_values.empty? && model.primary_key
        rel = rel.order(model.primary_key => :desc)
      end
      rel
    end

    def sort_by_expression(rel, column, expression)
      if model.column_names.include?(expression)
        rel = rel.reorder(model.arel_table[expression].public_send(sort_direction))
      else
        # Developer-supplied expression such as "customers.name"; join the association if there is one.
        ref = model.reflect_on_association(column.name)
        rel = rel.left_joins(column.name) if ref && !ref.polymorphic?
        rel = rel.reorder(Arel.sql("#{expression} #{sort_direction.to_s.upcase}"))
      end
      pk = model.primary_key
      pk && expression != pk ? rel.order(model.arel_table[pk].desc) : rel
    end
  end
end
