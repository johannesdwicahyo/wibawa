module Wibawa
  # A has_many block in a form (accepts_nested_attributes_for), with add,
  # remove and optional drag-to-reorder.
  #
  # Nested builders are created directly rather than with a fields_for block,
  # so no output is captured across component boundaries.
  class NestedFieldsComponent < BaseComponent
    NEW_INDEX = "NEW_RECORD".freeze
    GRID_COLS = { 1 => "sm:grid-cols-1", 2 => "sm:grid-cols-2", 3 => "sm:grid-cols-3", 4 => "sm:grid-cols-4" }.freeze

    def initialize(form:, field:, klass:)
      @form = form
      @field = field
      @klass = klass
    end

    attr_reader :form, :field, :klass

    def reflection
      @reflection ||= klass.reflect_on_association(field.name) ||
                      raise(Wibawa::Error, "#{klass} has no association :#{field.name}")
    end

    def child_class = reflection.klass
    def sortable = field.options[:sortable]
    def allow_destroy? = field.options.fetch(:allow_destroy, true)

    def label
      field.options[:label] || klass.human_attribute_name(field.name)
    end

    def add_label
      t("wibawa.form.add_nested", resource: child_class.model_name.human.downcase)
    end

    def children
      list = form.object.public_send(field.name).to_a
      return list unless sortable

      list.sort_by { |c| [ c.public_send(sortable) || Float::INFINITY, c.id || Float::INFINITY ] }
    end

    # The builder's template must be the view context, not this component:
    # FormBuilder calls @template.label(...), which would hit #label above.
    def builder_for(child, index)
      form.class.new("#{form.object_name}[#{field.name}_attributes][#{index}]", child, helpers, {})
    end

    def row(child, index)
      builder = builder_for(child, index)
      hidden = []
      hidden << builder.hidden_field(:id) if child.persisted?
      hidden << builder.hidden_field(sortable, data: { wb_position: true }) if sortable
      hidden << builder.hidden_field(:_destroy, value: child.marked_for_destruction? ? "1" : "0", data: { wb_destroy: true }) if allow_destroy?

      content_tag(:div, data: { wb_nested_item: true }, hidden: child.marked_for_destruction?,
                        class: "flex items-start gap-3 border-b border-line pb-3") do
        safe_join([
          (reorder_controls if sortable),
          content_tag(:div, class: "grid min-w-0 flex-1 gap-3 #{GRID_COLS[field.children.size.clamp(1, 4)]}") do
            safe_join(field.children.map do |child_field|
              render wibawa_component(:field, Wibawa::FieldComponent).new(form: builder, field: child_field, klass: child_class, compact: true)
            end)
          end,
          *hidden,
          (remove_button if allow_destroy?)
        ].compact)
      end
    end

    private

    # Dragging is one way to reorder; the arrows (and the arrow keys on the
    # handle) are the way that needs no drag.
    def reorder_controls
      content_tag(:div, safe_join([ handle, move_button("up"), move_button("down") ]), class: "mt-6 flex items-center")
    end

    def move_button(direction)
      content_tag(:button, icon("chevron-#{direction}", size: "size-4"), type: "button", data: { wb_nested_move: direction },
                           class: "rounded p-1 text-ink-3 hover:text-ink", "aria-label": t("wibawa.form.move_#{direction}"))
    end

    def handle
      content_tag(:button, type: "button", data: { wb_drag_handle: true }, draggable: true,
                           class: "cursor-grab rounded p-1 text-ink-3 hover:text-ink active:cursor-grabbing",
                           "aria-label": t("wibawa.form.reorder")) do
        icon("grip", size: "size-4")
      end
    end

    def remove_button
      content_tag(:button, type: "button", data: { wb_nested_remove: true },
                           class: "mt-6 rounded p-1 text-ink-3 hover:text-danger",
                           "aria-label": t("wibawa.form.remove")) do
        icon("x", size: "size-4")
      end
    end
  end
end
