module Wibawa
  # Record hits in the command palette, fetched as you type. wibawa.js moves
  # through the role="option" links, so keep that role on them.
  class SearchResultsComponent < BaseComponent
    # hits: [[resource, record, path], ...]
    def initialize(hits:)
      @hits = hits
    end

    attr_reader :hits

    def label(record) = presenter.display_name(record)
    # Shown beside the label: which kind of record this is.
    def hint(resource) = resource.singular_label
  end
end
