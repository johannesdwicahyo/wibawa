module Wibawa
  # Offset pagination. With `count: false` it skips COUNT(*) and only knows
  # whether a next page exists, which keeps huge tables fast.
  class Paginator
    attr_reader :page, :per_page

    def initialize(relation, page:, per_page:, count: true)
      @relation = relation
      @page = [page.to_i, 1].max
      @per_page = per_page
      @count = count
    end

    def counting? = @count

    def records
      @records ||= begin
        limit = @count ? per_page : per_page + 1
        rows = @relation.limit(limit).offset(offset).to_a
        unless @count
          @has_next = rows.size > per_page
          rows = rows.first(per_page)
        end
        rows
      end
    end

    def offset = (page - 1) * per_page

    def total_count
      return nil unless @count

      @total_count ||= @relation.except(:order, :limit, :offset, :includes, :preload, :eager_load).count(:all)
    end

    def total_pages
      return nil unless @count

      [(total_count.to_f / per_page).ceil, 1].max
    end

    def next?
      return page < total_pages if @count

      records
      @has_next
    end

    def prev? = page > 1
    def first_index = records.empty? ? 0 : offset + 1
    def last_index = offset + records.size

    # Page numbers with :gap markers, e.g. [1, :gap, 7, 8, 9, :gap, 40].
    def window(radius: 2)
      return [] unless @count

      last = total_pages
      pages = ([1, last] + ((page - radius)..(page + radius)).to_a).select { |p| p.between?(1, last) }.uniq.sort
      pages.each_with_object([]) do |p, out|
        out << :gap if out.any? && out.last != :gap && p - out.last > 1
        out << p
      end
    end
  end
end
