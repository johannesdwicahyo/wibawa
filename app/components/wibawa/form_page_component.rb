module Wibawa
  class FormPageComponent < BaseComponent
    def initialize(resource:, record:)
      @resource = resource
      @record = record
    end

    attr_reader :resource, :record

    def new_record? = record.new_record?

    def title
      new_record? ? t("wibawa.new_record", resource: resource.singular_label) : t("wibawa.edit_record", name: presenter.display_name(record))
    end

    def breadcrumbs
      crumbs = [ [ resource.label, resource.action?(:index) ? resources_path(resource: resource.key) : nil ] ]
      unless new_record?
        crumbs << [ presenter.display_name(record), resource.action?(:show) ? resource_path(resource: resource.key, id: record) : nil ]
      end
      crumbs << [ new_record? ? t("wibawa.new") : t("wibawa.edit"), nil ]
    end

    def form_url
      new_record? ? resources_path(resource: resource.key) : resource_path(resource: resource.key, id: record)
    end

    def cancel_url
      if !new_record? && resource.action?(:show) then resource_path(resource: resource.key, id: record)
      elsif resource.action?(:index) then resources_path(resource: resource.key)
      else root_path
      end
    end

    def items = resource.form_items
    def model = resource.model

    def base_errors = record.errors[:base]
    def errors? = record.errors.any?

    def multipart?
      model.respond_to?(:attachment_reflections) && model.attachment_reflections.any?
    end

    def render_item(form, item, klass)
      if item.kind == :has_many
        render wibawa_component(:nested_fields, Wibawa::NestedFieldsComponent).new(form: form, field: item, klass: klass)
      else
        render wibawa_component(:field, Wibawa::FieldComponent).new(form: form, field: item, klass: klass)
      end
    end
  end
end
