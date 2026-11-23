module Wibawa
  class PaginationComponent < BaseComponent
    def initialize(page:, form_id:)
      @page = page
      @form_id = form_id
    end

    attr_reader :page, :form_id

    def render? = page.records.any? || page.prev?

    def page_url(number)
      helpers.url_for(preserved_params("page").merge("page" => number))
    end

    def summary
      view = presenter.view
      if page.counting?
        t("wibawa.pagination.summary", from: view.number_with_delimiter(page.first_index),
                                       to: view.number_with_delimiter(page.last_index),
                                       total: view.number_with_delimiter(page.total_count))
      else
        t("wibawa.pagination.summary_uncounted", from: view.number_with_delimiter(page.first_index),
                                                 to: view.number_with_delimiter(page.last_index))
      end
    end

    def per_page_options
      (Wibawa.config.per_page_options | [page.per_page]).sort
    end

    def nav_class(enabled)
      class_names("inline-flex size-8 items-center justify-center rounded-lg text-sm",
                  "text-zinc-700 hover:bg-zinc-100 dark:text-zinc-300 dark:hover:bg-white/10" => enabled,
                  "pointer-events-none text-zinc-300 dark:text-zinc-700" => !enabled)
    end
  end
end
