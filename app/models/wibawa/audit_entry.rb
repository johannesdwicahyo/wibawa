module Wibawa
  # One change made through the admin: who, what, to which record, from the
  # browser or through the MCP server. Table and switch come from
  # `bin/rails g wibawa:audit_log`.
  #
  # Entries are shown through an ordinary read-only resource (see .resource),
  # so the log gets search, filters, CSV and authorization like any other page.
  class AuditEntry < (defined?(::ApplicationRecord) ? ::ApplicationRecord : ActiveRecord::Base)
    self.table_name = "wibawa_audit_entries"

    RESOURCE_KEY = "audit_log".freeze
    IGNORED = %w[created_at updated_at].freeze
    MAX_IDS = 1000

    # An entry is written once and never edited.
    def readonly? = persisted?

    def display_name = "#{action} #{record_label}".strip

    # ponytail: written right after the change, not in the same transaction.
    # If this insert fails the request errors but the change stays; wrap both
    # in a transaction if the log must be provably complete.
    def self.record!(user:, action:, resource:, via:, record: nil, data: nil)
      create!(
        actor: (("#{user.class.name}:#{user.id}" if user.respond_to?(:id) && user.id)), actor_label: label_for(user),
        action: action.to_s, via: via, resource_key: resource.key,
        record_id: record&.id&.to_s, record_label: record && label_for(record),
        data: filter(data)
      )
    end

    def self.label_for(object)
      return nil if object.nil?

      Wibawa.config.display_name_methods.each do |method|
        value = object.respond_to?(method) && object.public_send(method)
        return value.to_s if value.present?
      end
      object.respond_to?(:model_name) ? "#{object.model_name.human} ##{object.id}" : object.to_s
    end

    # Timestamps add nothing; secrets (the app's filter_parameters, plus the
    # columns Wibawa already hides from forms) are masked.
    def self.filter(data)
      return nil if data.blank?

      patterns = Rails.application.config.filter_parameters + [ Wibawa::Resource::HIDDEN_ATTRIBUTES ]
      ActiveSupport::ParameterFilter.new(patterns).filter(data.to_h.except(*IGNORED)).presence
    end

    # The page that shows the log. Define your own resource with
    # `as: "audit_log"` in app/wibawa to replace it. Labels are procs because
    # resources load before I18n is ready.
    def self.resource
      Wibawa::Resource.new(name, as: RESOURCE_KEY) do
        menu label: -> { I18n.t("wibawa.audit_log") }, icon: "file", priority: 99
        actions :index, :show
        search :record_label, :actor_label
        filter :resource_key, as: :select
        filter :action, as: :select
        filter :via, as: :select
        filter :created_at
        filter :record_id, as: :string, apply: ->(value) { where(record_id: value.to_s) }

        index sort: { created_at: :desc, id: :desc } do
          column :created_at
          column :actor_label, label: -> { I18n.t("wibawa.audit.who") }
          column :action, link: true
          column :resource_key, label: -> { I18n.t("wibawa.audit.resource") }
          column(:record_label, label: -> { I18n.t("wibawa.audit.record") }) do |entry|
            target = Wibawa.registry[entry.resource_key]
            if entry.record_id && entry.action != "destroy" && target&.action?(:show)
              link_to entry.record_label, resource_path(resource: target.key, id: entry.record_id), class: "font-medium text-ink underline-offset-4 hover:underline"
            else
              entry.record_label
            end
          end
          column :via
        end

        show do
          attributes :created_at, :actor_label, :actor, :action, :via, :resource_key, :record_id, :record_label
          row :data, as: :json, label: -> { I18n.t("wibawa.audit.changes") }
        end
      end
    end
  end
end
