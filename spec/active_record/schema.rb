module Mobility
  module Test
    if ENV['RAILS_VERSION'] == '4.2'
      parent_class = ::ActiveRecord::Migration
    else
      parent_class = ::ActiveRecord::Migration[[::ActiveRecord::VERSION::MAJOR, ::ActiveRecord::VERSION::MINOR].join(".")]
    end
    class Schema < parent_class
      class << self
        def up
          create_table "posts" do |t|
            t.boolean :published
            t.timestamps null: false
          end

          create_table "articles" do |t|
            t.string :slug
            t.boolean :published
            t.timestamps null: false
          end

          create_table "article_prices" do |t|
            t.string :currency
            t.integer :article_id
            t.string :title
            t.string :subtitle
            t.text :content
            t.timestamps null: false
          end

          create_table "multitable_posts" do |t|
            t.string :slug
            t.boolean :published
            t.timestamps null: false
          end

          create_table "multitable_post_prices" do |t|
            t.string :currency
            t.integer :multitable_post_id
            t.string :title
            t.timestamps null: false
          end

          create_table "multitable_post_foo_prices" do |t|
            t.string :currency
            t.integer :multitable_post_id
            t.string :foo
            t.timestamps null: false
          end

          create_table "mobility_integer_prices" do |t|
            t.string  :currency,          null: false
            t.string  :key,               null: false
            t.integer :value,             null: false
            t.integer :priceable_id,   null: false
            t.string  :priceable_type, null: false
            t.timestamps                  null: false
          end
          add_index :mobility_integer_prices, [:priceable_id, :priceable_type, :currency, :key], unique: true, name: :index_mobility_integer_prices_on_keys
          add_index :mobility_integer_prices, [:priceable_id, :priceable_type, :key], name: :index_mobility_integer_prices_on_priceable_attribute

          create_table "mobility_float_prices" do |t|
            t.string  :currency,          null: false
            t.string  :key,               null: false
            t.float   :value,             null: false
            t.integer :priceable_id,   null: false
            t.string  :priceable_type, null: false
            t.timestamps                  null: false
          end
          add_index :mobility_float_prices, [:priceable_id, :priceable_type, :currency, :key], unique: true, name: :index_mobility_float_prices_on_keys
          add_index :mobility_float_prices, [:priceable_id, :priceable_type, :key], name: :index_mobility_float_prices_on_priceable_attribute


          create_table "comments" do |t|
            t.text :content_en
            t.text :content_ja
            t.text :content_pt_br
            t.text :content_ru
            t.text :author_en
            t.text :author_ja
            t.text :author_pt_br
            t.text :author_ru
            t.boolean :published
            t.integer :article_id
            t.timestamps null: false
          end

          create_table "serialized_posts" do |t|
            t.text :my_title_i18n
            t.text :my_content_i18n
            t.boolean :published
            t.timestamps null: false
          end

          if ENV['DB'] == 'postgres'
            create_table "jsonb_posts" do |t|
              t.jsonb :my_title_i18n, default: {}
              t.jsonb :my_content_i18n, default: {}
              t.boolean :published
              t.timestamps null: false
            end

            create_table "json_posts" do |t|
              t.json :my_title_i18n, default: {}
              t.json :my_content_i18n, default: {}
              t.boolean :published
              t.timestamps null: false
            end

            create_table "container_posts" do |t|
              t.jsonb :prices, default: {}
              t.boolean :published
              t.timestamps null: false
            end

            execute "CREATE EXTENSION IF NOT EXISTS hstore"

            create_table "hstore_posts" do |t|
              t.hstore :my_title_i18n, default: ''
              t.hstore :my_content_i18n, default: ''
              t.boolean :published
              t.timestamps null: false
            end
          end
        end
      end
    end
  end
end
