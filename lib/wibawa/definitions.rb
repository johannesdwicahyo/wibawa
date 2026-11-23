module Wibawa
  # A column in an index table, show page, CSV export or dashboard table.
  Column = Struct.new(:name, :options, :block) do
    def as = options[:as]
    def link? = !!options[:link]

    def label
      options[:label] || Util.humanize(name)
    end

    # Returns the SQL to sort by, or nil when the column isn't sortable.
    # `sortable: "customers.name"` sorts by an arbitrary (developer-supplied) expression.
    def sort_expression(model)
      sortable = options[:sortable]
      return nil if sortable == false
      return sortable.to_s if sortable.is_a?(String) || sortable.is_a?(Symbol)
      return name.to_s if model.respond_to?(:column_names) && model.column_names.include?(name.to_s)

      nil
    end
  end

  Filter = Struct.new(:name, :options) do
    def as = options[:as]
    def label = options[:label] || Util.humanize(name)
  end

  Scope = Struct.new(:name, :body, :options) do
    def default? = !!options[:default]
    def label = options[:label] || Util.humanize(name)

    def apply(relation)
      return relation if name == :all && body.nil?
      return relation.instance_exec(&body) if body.is_a?(Proc)
      return relation.public_send(body) if body.is_a?(Symbol)

      relation.public_send(name)
    end
  end

  # kind is :field, :has_many or :section. children holds nested items.
  Field = Struct.new(:kind, :name, :options, :children) do
    def as = options[:as]
    def label = options[:label] || Util.humanize(name)
  end

  # Batch, member and dashboard actions.
  Action = Struct.new(:name, :options, :block) do
    def label = options[:label] || Util.humanize(name)
    def confirm = options[:confirm]
    def http_method = (options[:method] || :post).to_sym
    def destructive? = !!options[:destructive]
  end
end
