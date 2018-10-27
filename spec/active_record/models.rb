class Post < ActiveRecord::Base
  extend Mobility
  translates :title, backend: :key_value, cache: true, currency_accessors: true, dirty: true, type: :string, attribute_methods: true
  translates :content, backend: :key_value, cache: true, currency_accessors: true, dirty: true, type: :text, attribute_methods: true
end

class FallbackPost < ActiveRecord::Base
  self.table_name = "posts"
  extend Mobility
  translates :title, :content, backend: :key_value, type: :text, cache: true, currency_accessors: true, dirty: true, fallbacks: true
end

class MultitablePost < ActiveRecord::Base
  extend Mobility
  translates :title,
    backend:          :table,
    table_name:       :multitable_post_prices,
    association_name: :prices
  translates :foo,
    backend:          :table,
    table_name:       :multitable_post_foo_prices,
    association_name: :foo_prices
end
