module Wibawa
  # One admin resource, built from the DSL in app/wibawa/*.rb.
  class Resource
    CRUD_ACTIONS = %i[index show new create edit update destroy].freeze
    # Columns that hold a secret, whole name or last word: `digest`, `password_digest`,
    # `api_key`, `pin_hash`, `otp_secret`. Never offered by default; the audit log masks them.
    # So is anything the model declares with `encrypts` (see .secret?).
    SECRET_ATTRIBUTES = /\A(encrypted_.*|.*_ciphertext|.*_hash|.*_key|(.*_)?(digest|token|secret|salt|password))\z/
    HIDDEN_ATTRIBUTES = Regexp.union(/\A(id|created_at|updated_at|lock_version)\z/, SECRET_ATTRIBUTES)

    # Whether a column should stay out of default pages and generated files:
    # its name looks secret, or the model encrypts it.
    def self.secret?(klass, name)
      name.to_s.match?(SECRET_ATTRIBUTES) ||
        (klass.respond_to?(:encrypted_attributes) && Array(klass.encrypted_attributes).map(&:to_s).include?(name.to_s))
    end

    attr_reader :model_name, :options, :scopes, :filters, :search_fields, :member_actions,
                :controller_blocks, :menu_options, :include_associations

    def initialize(model, **options, &block)
      # Keep the class itself: the registry is rebuilt on every code reload,
      # so this never points at a stale class.
      @model_class = model.is_a?(String) ? nil : model
      @model_name = model.is_a?(String) ? model : model.name
      @options = options
      @scopes = []
      @filters = []
      @search_fields = nil
      @batch_actions = []
      @disabled_batch_actions = []
      @member_actions = []
      @controller_blocks = []
      @include_associations = []
      @menu_options = {}
      actions(*Wibawa.config.default_actions) # the panel's default; `actions` in the block replaces it
      @index = nil
      @show = nil
      @form = nil
      @csv = nil
      @permitted = nil
      instance_eval(&block) if block
    end

    # ---- DSL ---------------------------------------------------------------

    #   menu label: "Orders", group: "Sales", priority: 1, icon: "receipt"
    #   menu false
    def menu(value = nil, **options)
      @menu_options = value == false ? false : options
    end

    #   scope :all, default: true
    #   scope :pending, -> { where(status: :pending) }
    #   scope :recent                # calls Order.recent
    def scope(name, body = nil, default: false, label: nil, count: nil)
      @scopes << Scope.new(name.to_sym, body, { default: default, label: label, count: count }.compact)
    end

    #   filter :status, as: :select
    #   filter :created_at, as: :date_range
    #   filter :customer                  # belongs_to: select of customers
    #   filter :q, as: :search, on: [:number, "customer.name"]
    def filter(name, as: nil, **options)
      @filters << Filter.new(name.to_sym, options.merge(as: as).compact)
    end

    # The search box above the table. Dotted names search associations.
    #   search :number, :email, "customer.name"
    def search(*fields)
      @search_fields = fields.flatten.map(&:to_s)
    end

    # Eager-load associations used in columns (also inferred automatically).
    def includes(*associations)
      @include_associations.concat(associations.flatten)
    end

    #   actions :all, except: [:destroy]
    #   actions :index, :show
    def actions(*list, except: [])
      list = CRUD_ACTIONS if list.empty? || list == [ :all ]
      list = list.map(&:to_sym)
      list |= [ :create ] if list.include?(:new)
      list |= [ :update ] if list.include?(:edit)
      excluded = Array(except).map(&:to_sym)
      excluded |= [ :create ] if excluded.include?(:new)
      excluded |= [ :update ] if excluded.include?(:edit)
      @allowed_actions = list - excluded
    end

    #   index density: :compact   # 32 px rows instead of 40
    def index(per_page: nil, sort: nil, count: true, density: nil, &block)
      raise Error, "Unknown density #{density.inspect} (use :compact)" unless [ nil, :compact, "compact" ].include?(density)

      @index = IndexBuilder.new(per_page: per_page, sort: sort, count: count, density: density)
      @index.instance_eval(&block) if block
    end

    def show(&block)
      @show = ShowBuilder.new
      @show.instance_eval(&block) if block
    end

    def form(&block)
      @form = FormBuilder.new
      @form.instance_eval(&block) if block
    end

    def csv(&block)
      @csv = TableBuilder.new
      @csv.instance_eval(&block) if block
    end

    # Turn on CSV import for this resource:
    #   import                          # every row creates a record
    #   import key: :number             # rows whose number exists update that record
    #   import only: %i[number total]   # limit the columns (default: the form's fields)
    def import(key: nil, only: nil)
      @import = { key: key&.to_sym, only: only&.map(&:to_sym) }
    end

    # Explicit strong params. Normally inferred from the form.
    def permit_params(*attributes)
      @permitted = attributes.flatten
    end

    #   batch_action :mark_paid, confirm: "Mark selected orders as paid?" do |orders|
    #     orders.update_all(status: :paid)
    #     "#{orders.size} orders marked as paid"
    #   end
    #   batch_action :destroy, false      # turn off the built-in batch delete
    def batch_action(name, enabled = true, label: nil, confirm: nil, &block)
      name = name.to_sym
      if enabled == false
        @disabled_batch_actions << name
      else
        @batch_actions << Action.new(name, { label: label, confirm: confirm }.compact, block)
      end
    end

    #   member_action :refund, confirm: "Refund this order?" do |order|
    #     order.refund!
    #     "Order refunded"
    #   end
    def member_action(name, method: :post, label: nil, confirm: nil, destructive: false, &block)
      opts = { method: method, label: label, confirm: confirm, destructive: destructive }.compact
      @member_actions << Action.new(name.to_sym, opts, block)
    end

    # Override controller hooks for this resource only:
    #   controller do
    #     def scoped_collection = super.where(tenant: Current.tenant)
    #   end
    def controller(&block)
      @controller_blocks << block
    end

    # ---- Reading the definition --------------------------------------------

    def model
      @model_class || Object.const_get(@model_name)
    end

    def key
      (@options[:as] || Util.route_key(@model_name)).to_s
    end

    def menu?
      @menu_options != false
    end

    def label
      if menu? && (custom = @menu_options[:label])
        return custom.respond_to?(:call) ? custom.call : custom
      end

      return Util.humanize(key) unless model.respond_to?(:model_name)

      # An i18n plural wins; otherwise inflect (a no-op for locales without rules, e.g. :id).
      name = model.model_name
      name.human(count: 2, default: name.human.pluralize(I18n.locale))
    end

    def singular_label
      model.respond_to?(:model_name) ? model.model_name.human : Util.humanize(Util.singularize(key))
    end

    def menu_group = menu? ? @menu_options[:group] : nil
    def menu_priority = menu? ? (@menu_options[:priority] || 10) : 10
    def menu_icon = (menu? && @menu_options[:icon]) || "table"
    def menu_visible_if = menu? ? @menu_options[:if] : nil

    def action?(action)
      @allowed_actions.include?(action.to_sym)
    end

    def index_options
      { per_page: nil, sort: nil, count: true, density: nil }.merge(@index&.options || {})
    end

    def index_columns
      cols = @index&.columns
      cols && !cols.empty? ? cols : default_columns
    end

    def row_actions
      return @index.row_actions if @index&.row_actions

      { only: nil, block: nil }
    end

    def selectable?
      explicit = @index&.selectable?
      explicit.nil? ? !batch_actions.empty? : explicit
    end

    def batch_actions
      list = @batch_actions.dup
      if action?(:destroy) && !@disabled_batch_actions.include?(:destroy) && list.none? { |a| a.name == :destroy }
        list << Action.new(:destroy, { label: "Delete", confirm: true, destructive: true }, nil)
      end
      list
    end

    def find_batch_action(name) = batch_actions.find { |a| a.name.to_s == name.to_s }
    def find_member_action(name) = member_actions.find { |a| a.name.to_s == name.to_s }

    def show_items
      return @show.items if @show && !@show.items.empty?

      default_show_columns.map { |c| [ :row, c ] }
    end

    def form_items
      @form && !@form.items.empty? ? @form.items : default_form_items
    end

    def csv_columns
      @csv && !@csv.columns.empty? ? @csv.columns : index_columns
    end

    def default_scope
      scopes.find(&:default?) || scopes.first
    end

    def find_scope(name)
      scopes.find { |s| s.name.to_s == name.to_s }
    end

    def importable? = !@import.nil?
    def import_options = @import || {}

    # Columns a CSV may set: plain attributes only, no nested rows or lists.
    def import_attributes
      import_options[:only] || permitted_attributes.grep(Symbol)
    end

    # Strong-params list, inferred from the form unless permit_params was used.
    def permitted_attributes
      @permitted || attributes_for(form_items, model)
    end

    # { "Customer" => Customer }: the models this resource's form fields (nested
    # ones too) and filters let you choose from. Only these can be searched through
    # the options endpoint.
    def option_classes
      classes = choice_classes(form_items, model)
      filters.each do |filter|
        klass, column = Query.target(model, filter.name)
        ref = klass.reflect_on_association(column.to_sym)
        classes << ref.klass if ref && !ref.polymorphic? && Query::CHOICE_MACROS.include?(ref.macro)
      end
      classes.uniq.index_by(&:name)
    end

    # Associations to eager-load on the index page.
    def index_includes
      list = @include_associations.dup
      return list unless model.respond_to?(:reflect_on_association)

      index_columns.each do |col|
        next if col.block

        ref = model.reflect_on_association(col.name)
        list << col.name if ref && !ref.polymorphic?
        list << { "#{col.name}_attachment": :blob } if model.respond_to?(:reflect_on_attachment) && model.reflect_on_attachment(col.name)
      end
      list.uniq
    end

    private

    def choice_classes(items, klass)
      items.flat_map do |item|
        ref = klass.reflect_on_association(item.name) unless item.kind == :section
        case item.kind
        when :section then choice_classes(item.children, klass)
        when :has_many then ref ? choice_classes(item.children, ref.klass) : []
        else ref && !ref.polymorphic? && %i[belongs_to has_many has_and_belongs_to_many].include?(ref.macro) ? [ ref.klass ] : []
        end
      end
    end

    def content_attribute_names
      return [] unless model.respond_to?(:columns)

      foreign_keys = belongs_to_reflections.to_h { |r| [ r.foreign_key.to_s, r.name ] }
      model.columns.filter_map do |c|
        next if c.name.match?(HIDDEN_ATTRIBUTES) || self.class.secret?(model, c.name)
        next if c.name.end_with?("_type") && foreign_keys.key?(c.name.sub(/_type\z/, "_id"))

        foreign_keys.fetch(c.name, c.name).to_sym
      end
    end

    def belongs_to_reflections
      return [] unless model.respond_to?(:reflect_on_all_associations)

      model.reflect_on_all_associations(:belongs_to)
    end

    def default_columns
      names = content_attribute_names.reject do |n|
        col = model.columns_hash[n.to_s]
        col && %i[text json jsonb binary].include?(col.type)
      end
      cols = [ Column.new(:id, { link: true }, nil) ]
      names.first(6).each { |n| cols << Column.new(n, {}, nil) }
      cols << Column.new(:created_at, {}, nil) if model.column_names.include?("created_at")
      cols
    end

    def default_show_columns
      names = [ :id ] + content_attribute_names + declared_content_names
      names += %i[created_at updated_at].select { |n| model.column_names.include?(n.to_s) }
      names.map { |n| Column.new(n, {}, nil) }
    end

    def default_form_items
      (content_attribute_names + declared_content_names).map { |n| Field.new(:field, n, {}, []) }
    end

    # Active Storage attachments and Action Text attributes: declared on the model, not columns of its table.
    def declared_content_names
      attachments = model.respond_to?(:attachment_reflections) ? model.attachment_reflections.keys : []
      rich_texts = model.respond_to?(:rich_text_association_names) ? model.rich_text_association_names.map { |name| name.to_s.delete_prefix("rich_text_") } : []
      (attachments + rich_texts).map(&:to_sym)
    end

    def attributes_for(items, klass)
      items.flat_map do |item|
        case item.kind
        when :section
          attributes_for(item.children, klass)
        when :has_many
          ref = klass.reflect_on_association(item.name)
          raise Error, "#{klass} has no association :#{item.name}" unless ref

          nested = attributes_for(item.children, ref.klass)
          nested << item.options[:sortable].to_sym if item.options[:sortable]
          [ { "#{item.name}_attributes": [ :id, :_destroy, *nested ].uniq } ]
        else
          [ attribute_for_field(item, klass) ]
        end
      end
    end

    def attribute_for_field(field, klass)
      name = field.name
      return { name => [] } if field.options[:multiple]

      if klass.respond_to?(:reflect_on_attachment) && (att = klass.reflect_on_attachment(name))
        return att.macro == :has_many_attached ? { name => [] } : name
      end

      ref = klass.respond_to?(:reflect_on_association) && klass.reflect_on_association(name)
      return name unless ref

      case ref.macro
      when :belongs_to then ref.foreign_key.to_sym
      when :has_many, :has_and_belongs_to_many then { "#{Util.singularize(name)}_ids": [] }
      else name
      end
    end
  end
end
