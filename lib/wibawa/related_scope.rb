module Wibawa
  # A user who may see a record is not thereby allowed to see, or to choose,
  # the records it points at. This asks the authorization's scope for the
  # other model, in the three places that matter: showing a related record's
  # name, saving a newly chosen related record, and filtering through one.
  #
  # It only knows `config.authorization` (the policy scope). A `scoped_collection`
  # written in a resource's `controller do` block is that resource's own and
  # is not consulted for records reached from another resource.
  #
  # One per request: what it learns is kept for the rest of the page.
  class RelatedScope
    def initialize(authorizer)
      @authorizer = authorizer
      @restricted = {}
      @seen = Hash.new { |hash, klass| hash[klass] = { known: Set.new, visible: Set.new } }
    end

    # The relation narrowed to what the user may see. A model with no policy
    # of its own has no rule to apply, and comes back as it was.
    def scope(relation)
      @authorizer.scope(relation)
    rescue StandardError => e
      raise unless e.class.name.match?(/NotDefined|NotFound/) # Pundit::NotDefinedError, ActionPolicy::NotFound

      relation
    end

    # False when the user may see every record of the model, which is always
    # so without `config.authorization`. Nothing is queried then.
    def restricted?(klass)
      @restricted.fetch(klass) { @restricted[klass] = scope(klass.all).to_sql != klass.all.to_sql }
    end

    def visible?(record)
      klass = record.class
      return true if record.new_record? || !restricted?(klass)

      seen = @seen[klass]
      look_up(klass, [ record.id ]) unless seen[:known].include?(record.id)
      seen[:visible].include?(record.id)
    end

    # Before a page of `records` is drawn: one query per belongs_to among
    # `names`, in place of one per row.
    def prime(records, names)
      model = records.first&.class
      return unless model.respond_to?(:reflect_on_association)

      names.each do |name|
        ref = model.reflect_on_association(name)
        next unless ref&.macro == :belongs_to && !ref.polymorphic? && restricted?(ref.klass)

        look_up(ref.klass, records.filter_map { |record| record[ref.foreign_key] }.uniq - @seen[ref.klass][:known].to_a)
      end
    end

    # { attribute key => association name } for each attribute that would point
    # `record` at a related record the user may not see. Only what changes is
    # judged: a value the record already has is left alone, so a record can
    # still be edited by someone who cannot see everything it points at.
    def outside(record, attributes)
      klass = record.class
      return {} unless klass.respond_to?(:reflect_on_all_associations)

      attributes = attributes.to_h.transform_keys(&:to_s)
      klass.reflect_on_all_associations.each_with_object({}) do |ref, rejected|
        next if ref.polymorphic? || ref.options[:through]

        key = written_key(ref, attributes) or next
        rejected[key] = ref.name if newly_chosen_outside?(record, ref, attributes[key])
      end
    end

    private

    def look_up(klass, ids)
      return if ids.empty?

      @seen[klass][:known].merge(ids)
      @seen[klass][:visible].merge(scope(klass.all).where(klass.primary_key => ids).pluck(klass.primary_key))
    end

    def written_key(ref, attributes)
      candidates =
        case ref.macro
        when :belongs_to then [ ref.foreign_key.to_s ]
        when :has_many, :has_and_belongs_to_many then [ "#{ref.name.to_s.singularize}_ids", "#{ref.name}_attributes" ]
        else []
        end
      candidates.find { |key| attributes.key?(key) }
    end

    def newly_chosen_outside?(record, ref, value)
      if value.is_a?(Hash) || (value.is_a?(Array) && value.first.is_a?(Hash))
        nested_outside?(record, ref, value)
      elsif ref.macro == :belongs_to
        value.present? && value.to_s != record[ref.foreign_key].to_s && !all_visible?(ref.klass, [ value ])
      else
        current = record.new_record? ? [] : record.public_send(ref.name).pluck(ref.klass.primary_key).map(&:to_s)
        !all_visible?(ref.klass, Array(value).compact_blank.map(&:to_s) - current)
      end
    end

    # accepts_nested_attributes_for: each row is judged as its own record.
    def nested_outside?(record, ref, rows)
      rows = rows.values if rows.is_a?(Hash)
      existing = record.new_record? ? {} : record.public_send(ref.name).index_by { |child| child.id.to_s }
      rows.any? do |row|
        row = row.to_h.transform_keys(&:to_s)
        outside(existing[row["id"].to_s] || ref.klass.new, row).any?
      end
    end

    def all_visible?(klass, ids)
      ids = ids.map(&:to_s).uniq
      ids.empty? || !restricted?(klass) || scope(klass.all).where(klass.primary_key => ids).count == ids.size
    end
  end
end
