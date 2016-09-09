require 'json'
require 'base64'

class Cursory::Base
  attr_accessor *%i{criteria sort limit offset cursor}

  MAX_LIMIT = 100
  SORT_KEY, LIMIT_KEY, CURSOR_KEY, OFFSET_KEY = %i{sort limit cursor offset}

  def initialize criteria, params
    @criteria = criteria
    @sort = params[SORT_KEY]
    @limit = params[LIMIT_KEY]
    @offset = params[OFFSET_KEY]
    @cursor = params[CURSOR_KEY]
  end

  def page
    { total_count: count, items: search_results, self: current_cursor }.tap do |p|
      catch(:no_more_results) do
        p[:next] = next_cursor
      end
    end
  end

  def search
    constrained_search.send(*search_type)
  end

  def search_type
    fail UnimplementedError
  end

  def clamped_offset
    [0, offset.to_i].max
  end

  def constrained_search
    fail UnimplementedError
  end

  def search_results
    @results ||= uncached_search
  end

  def uncached_search
    fail UnimplementedError
  end

  def current_cursor
    cursor || render_cursor
  end

  def record_for_next_cursor
    search_results[clamped_limit-1] or throw(:no_more_results)
  end

  def next_cursor
    if record_for_next_cursor
      render_cursor cursor_data(id: record_for_next_cursor.id.to_s)
    end
  end

  def count
    @count ||= criteria.count
  end

  def uncached_count
    fail UnimplementedError
  end

  def sort_keys
    sort || model_sort || ''
  end

  def model
    fail UnimplementedError
  end

  def model_sort
    model.respond_to?(:default_sort_key) && model.default_sort_key
  end

  def order_keys
    sort_keys.split(',').map{ |k| decompose_order_key(k) } + [[:id, 'asc']]
  end

  def decompose_order_key(k)
    [ k.gsub(/\A[-+]?/,'').to_sym, k.start_with?('-') ? 'desc' : 'asc' ]
  end

  def order_clause
    fail UnimplementedError
  end

  def clamped_limit
    [1, limit.to_i, MAX_LIMIT].sort[1]
  end

  def cursor_clauses
    fail UnimplementedError
  end

  def cursor_clause_set
    keys = []
    Enumerator.new do |y|
      order_keys.each do |key|
        y.yield cursor_clause(key, keys).reduce(&:merge)
        keys << key
      end
    end
  end

  def cursor_clause(key, keys=[])
    name, direction = key
    Enumerator.new do |y|
      keys.each do |name, direction|
        y.yield clause_for_key(name, 'eq')
      end
      y.yield clause_for_key(name, direction)
    end
  end

  def clause_for_key key, direction
    fail UnimplementedError
  end

  def cursor_object
    @cursor_object ||= uncached_cursor_object
  end

  def uncached_cursor_object
    fail UnimplementedError
  end

  def render_cursor(data={})
    ::Base64.urlsafe_encode64(JSON.dump(data))
  end

  def parsed_cursor
    JSON.parse(::Base64.urlsafe_decode64(cursor || 'e30='))
  rescue ArgumentError, JSON::ParserError
    raise InvalidCursorError
  end

  def cursor_id
    cursor_data['id']
  end

  def cursor_data(overrides={})
    (parsed_cursor || {}).merge(overrides)
  end

  class InvalidCursorError < StandardError; end
end
