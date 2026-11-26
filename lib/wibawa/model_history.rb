module Wibawa
  # A record's own change history, read from PaperTrail or Audited when its
  # model uses one. Unlike Wibawa's audit log, this covers changes made
  # anywhere in the app: the console, jobs, the app's own controllers.
  module ModelHistory
    Entry = Struct.new(:at, :who, :event, :changes)
    LIMIT = 20
    NOISE = %w[id created_at updated_at lock_version].freeze # in every version, and tell the reader nothing

    # The newest entries first, or nil when the model uses neither gem.
    # `only` names the attributes whose changes may be shown; secrets among
    # them are masked the way the audit log masks them.
    def self.for(record, only:, limit: LIMIT)
      klass = record.class
      entries =
        if klass.respond_to?(:versions_association_name) # PaperTrail
          record.public_send(klass.versions_association_name).reorder(created_at: :desc, id: :desc).limit(limit).map do |version|
            Entry.new(version.created_at, version.whodunnit.presence, version.event, changeset(version))
          end
        elsif klass.respond_to?(:audited_options) # Audited
          record.audits.reorder(version: :desc).includes(:user).limit(limit).map do |audit|
            Entry.new(audit.created_at, audit.user && Wibawa::AuditEntry.label_for(audit.user), audit.action, pairs(audit))
          end
        end
      entries&.each { |entry| entry.changes = Wibawa::AuditEntry.filter(entry.changes.to_h.slice(*only.map(&:to_s) - NOISE)) || {} }
    end

    # ponytail: a version whose changes cannot be read (no object_changes
    # column, or YAML the app has not permitted) is listed without them rather
    # than breaking the record's page.
    def self.changeset(version)
      version.changeset.to_h
    rescue StandardError
      {}
    end

    # Audited stores [old, new] for an update and bare values otherwise.
    def self.pairs(audit)
      changes = audit.audited_changes || {}
      case audit.action
      when "create" then changes.transform_values { |value| [ nil, value ] }
      when "destroy" then changes.transform_values { |value| [ value, nil ] }
      else changes
      end
    end
  end
end
