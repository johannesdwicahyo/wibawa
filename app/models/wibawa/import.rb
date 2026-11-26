module Wibawa
  # One CSV import that runs in a background job: the uploaded file while it
  # waits, then what the import did. Table and switch come from
  # `bin/rails g wibawa:background_import`.
  class Import < (defined?(::ApplicationRecord) ? ::ApplicationRecord : ActiveRecord::Base)
    self.table_name = "wibawa_imports"

    # ponytail: the file is parsed whole, in memory, and imported in one
    # transaction, as in a request. Read it in batches before raising this.
    MAX_ROWS = 100_000

    # An import belongs to whoever started it, like a saved view.
    scope :visible_to, ->(user) { where(owner: Wibawa::SavedView.owner_key(user)) }

    def queued? = status == "queued"
    def waiting? = %w[queued running].include?(status)
    def failed? = status == "failed"

    # A resource can run in the background when nothing about the import
    # depends on the request: no `controller do` overrides (a scoped_collection
    # there would not apply in a job), and a user the job can find again.
    def self.possible?(resource, user)
      Wibawa.config.background_import && resource.controller_blocks.empty? && (user.nil? || user.respond_to?(:to_global_id))
    end

    def self.start!(resource, user, text, filename:, dry_run:)
      import = create!(resource_key: resource.key, owner: Wibawa::SavedView.owner_key(user), user_gid: user&.to_global_id&.to_s,
                       filename: filename.to_s.first(200), dry_run: dry_run, file: text.b)
      Wibawa::ImportJob.perform_later(import.id)
      import
    end

    # What the import did, in the shape the importer returns it.
    def outcome
      data = result || {}
      Wibawa::CsvImporter::Result.new(data["created"].to_i, data["updated"].to_i, data["errors"] || [], dry_run, data["preview"] || [])
    end

    # Runs the import as the user who started it, through the same
    # authorization as the request would: `:import` on the model, the policy
    # scope for lookups, and `create` or `update` on each row.
    def run!
      update!(status: "running", started_at: Time.current)
      resource = Wibawa.registry.fetch(resource_key)
      user = user_gid && GlobalID::Locator.locate(user_gid)
      authorizer = Wibawa::Authorization.build(user)
      raise Wibawa::NotAuthorized, I18n.t("wibawa.flash.not_authorized") if (user_gid && user.nil?) || !authorizer.authorized?(:import, resource.model)

      importer = Wibawa::CsvImporter.new(resource, find_in: authorizer.scope(resource.model.all), build: -> { resource.model.new },
                                                   authorize: ->(action, record) { authorizer.authorized?(action, record) })
      done = importer.call(file, dry_run: dry_run, max_rows: MAX_ROWS)
      if done.ok? && !dry_run && Wibawa.config.audit_log
        Wibawa::AuditEntry.record!(user: user, action: :import, resource: resource, via: "web", data: { created: done.created, updated: done.updated })
      end
      finish("finished", created: done.created, updated: done.updated, errors: done.errors, preview: done.preview)
    rescue StandardError => e
      # Nothing was kept (the import is one transaction), so the job is not retried: the user uploads again.
      finish("failed", errors: [ [ nil, e.message.to_s.first(500) ] ])
    end

    private

    # The file is dropped once it has been read: the row stays as the record of what happened.
    def finish(status, result)
      update!(status: status, finished_at: Time.current, file: nil, result: result)
    end
  end
end
