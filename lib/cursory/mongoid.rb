require 'cursory/base'

module Cursory
  class Mongoid < Base
    def search_type
      if cursor
        [:where, cursor_clauses]
      else
        [:skip, clamped_offset]
      end
    end

    def constrained_search
      criteria.order_by(order_clause).limit(clamped_limit)
    end

    def uncached_count
      criteria.count
    end

    def model
      criteria.klass
    end

    def uncached_search
      search.to_a
    end

    def order_clause
      order_keys.inject({}) { |hash, (key, value)| hash[key] = value; hash }
    end

    def cursor_clauses
      if cursor_id
        { '$or' => cursor_clause_set.to_a }
      end
    end

    def clause_for_key key, direction
      { key.to_sym => { key_for_direction(direction) => cursor_object.send(key) } }
    end

    def key_for_direction(d)
      {
        'eq'   => '$eq',
        'asc'  => '$gt',
        'desc' => '$lt'
      }[d]
    end

    def uncached_cursor_object
      criteria.klass.find(cursor_id)
    end
  end
end
