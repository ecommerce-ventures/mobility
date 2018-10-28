require "sequel/extensions/migration"
Sequel::Model.plugin :timestamps, update_on_create: true

module Mobility
  module Test
    class Schema
      class << self
        def migrate(*)
          DB.create_table? :posts do
            primary_key :id
            TrueClass   :published
            DateTime    :created_at, allow_null: false
            DateTime    :updated_at, allow_null: false
          end

          DB.create_table? :post_metadatas do
            primary_key :id
            String      :metadata
            Integer     :post_id,    allow_null: false
            DateTime    :created_at, allow_null: false
            DateTime    :updated_at, allow_null: false
          end

          DB.create_table? :articles do
            primary_key :id
            String      :slug
            TrueClass   :published
            DateTime    :created_at, allow_null: false
            DateTime    :updated_at, allow_null: false
          end

          DB.create_table? :article_prices do
            primary_key :id
            Integer     :article_id, allow_null: false
            String      :currency,     allow_null: false
            String      :title
            Integer     :total
            String      :content, size: 65535
            DateTime    :created_at, allow_null: false
            DateTime    :updated_at, allow_null: false
          end

          DB.create_table? :multitable_posts do
            primary_key :id
            TrueClass   :published
            DateTime    :created_at, allow_null: false
            DateTime    :updated_at, allow_null: false
          end

          DB.create_table? :multitable_post_prices do
            primary_key :id
            Integer     :multitable_post_id, allow_null: false
            String      :currency,             allow_null: false
            String      :title
            DateTime    :created_at,         allow_null: false
            DateTime    :updated_at,         allow_null: false
          end


          DB.create_table? :multitable_post_foo_prices do
            primary_key :id
            Integer     :multitable_post_id, allow_null: false
            String      :currency,             allow_null: false
            String      :foo
            DateTime    :created_at,         allow_null: false
            DateTime    :updated_at,         allow_null: false
          end

          DB.create_table? :mobility_integer_prices do
            primary_key :id
            String      :currency,            allow_null: false
            String      :key
            String      :value
            Integer     :priceable_id,   allow_null: false
            String      :priceable_type, allow_null: false
            DateTime    :created_at,        allow_null: false
            DateTime    :updated_at,        allow_null: false
            index [:priceable_id, :priceable_type, :currency, :key], unique: true, name: :index_mobility_integer_prices_on_keys
            index [:priceable_id, :priceable_type, :key], name: :index_mobility_integer_prices_on_priceable_attribute
          end

          DB.create_table? :comments do
            primary_key :id
            String      :content_en,    size: 65535
            String      :content_ja,    size: 65535
            String      :content_pt_br, size: 65535
            String      :content_ru,    size: 65535
            String      :author_en
            String      :author_ja
            String      :author_pt_br
            String      :author_ru
            TrueClass   :published
            Integer     :article_id
            DateTime    :created_at, allow_null: false
            DateTime    :updated_at, allow_null: false
          end

          DB.create_table? :serialized_posts do
            primary_key :id
            String      :my_title_prices,   size: 65535
            String      :my_content_prices, size: 65535
            TrueClass   :published
            DateTime    :created_at,                   allow_null: false
            DateTime    :updated_at,                   allow_null: false
          end

          if ENV['DB'] == 'postgres'
            DB.create_table? :jsonb_posts do
              primary_key :id
              jsonb       :my_title_prices,   default: '{}', allow_null: false
              jsonb       :my_content_prices, default: '{}', allow_null: false
              TrueClass   :published
              DateTime    :created_at,                     allow_null: false
              DateTime    :updated_at,                     allow_null: false
            end

            DB.create_table? :json_posts do
              primary_key :id
              json        :my_title_prices,   default: '{}', allow_null: false
              json        :my_content_prices, default: '{}', allow_null: false
              TrueClass   :published
              DateTime    :created_at,                     allow_null: false
              DateTime    :updated_at,                     allow_null: false
            end

            DB.create_table? :container_posts do
              primary_key :id
              jsonb       :prices, default: '{}',    allow_null: false
              TrueClass   :published
              DateTime    :created_at,                     allow_null: false
              DateTime    :updated_at,                     allow_null: false
            end

            DB.run "CREATE EXTENSION IF NOT EXISTS hstore"
            DB.create_table? :hstore_posts do
              primary_key :id
              hstore      :my_title_prices, default: '',   allow_null: false
              hstore      :my_content_prices, default: '', allow_null: false
              TrueClass   :published
              DateTime    :created_at,                   allow_null: false
              DateTime    :updated_at,                   allow_null: false
            end
          end
        end

        def up
          migrate(:up)
        end
      end
    end
  end
end
