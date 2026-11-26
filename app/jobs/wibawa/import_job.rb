module Wibawa
  # Runs one background CSV import (see Wibawa::Import). To choose its queue:
  #   Rails.application.config.to_prepare { Wibawa::ImportJob.queue_as :low }
  class ImportJob < (defined?(::ActiveJob::Base) ? ::ActiveJob::Base : Object)
    def perform(import_id)
      import = Wibawa::Import.find_by(id: import_id)
      import.run! if import&.queued? # a job delivered twice does nothing the second time
    end
  end
end
