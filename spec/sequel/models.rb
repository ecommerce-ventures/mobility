Sequel::Model.db = DB

class Post < Sequel::Model
  plugin :mobility
  translates :title, backend: :key_value, cache: true, currency_accessors: true, dirty: true, type: :string
  translates :content, backend: :key_value, cache: true, currency_accessors: true, dirty: true, type: :text
end

class FallbackPost < Sequel::Model(DB[:posts])
  plugin :mobility
  translates :title, :content, backend: :key_value, type: :text, cache: true, currency_accessors: true, dirty: true, fallbacks: true
end

class MultitablePost < Sequel::Model
  plugin :mobility
  translates :title,
    backend:          :table,
    table_name:       :multitable_post_prices,
    association_name: :prices
  translates :foo,
    backend:          :table,
    table_name:       :multitable_post_foo_prices,
    association_name: :foo_prices
end
