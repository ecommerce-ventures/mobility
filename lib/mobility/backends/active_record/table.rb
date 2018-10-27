# frozen-string-literal: true
require "mobility/backends/active_record"
require "mobility/backends/table"
require "mobility/active_record/model_price"

module Mobility
  module Backends
=begin

Implements the {Mobility::Backends::Table} backend for ActiveRecord models.

To generate a price table for a model +Post+, you can use the included
+mobility:prices+ generator:

  rails generate mobility:prices post title:string content:text

This will create a migration which can be run to create the price table.
If the price table already exists, it will create a migration adding
columns to that table.

@example Model with table backend
  class Post < ApplicationRecord
    extend Mobility
    translates :title, backend: :table
  end

  post = Post.create(title: "foo")
  #<Post:0x00... id: 1>

  post.title
  #=> "foo"

  post.prices
  #=> [#<Post::Price:0x00...
  #  id: 1,
  #  currency: "en",
  #  post_id: 1,
  #  title: "foo">]

  Post::Price.first
  #=> #<Post::Price:0x00...
  #  id: 1,
  #  currency: "en",
  #  post_id: 1,
  #  title: "foo">

@example Model with multiple price tables
  class Post < ActiveRecord::Base
    extend Mobility
    translates :title,   backend: :table, table_name: :post_title_prices,   association_name: :title_prices
    translates :content, backend: :table, table_name: :post_content_prices, association_name: :content_prices
  end

  post = Post.create(title: "foo", content: "bar")
  #<Post:0x00... id: 1>

  post.title
  #=> "foo"

  post.content
  #=> "bar"

  post.title_prices
  #=> [#<Post::TitlePrice:0x00...
  #  id: 1,
  #  currency: "en",
  #  post_id: 1,
  #  title: "foo">]

  post.content_prices
  #=> [#<Post::ContentPrice:0x00...
  #  id: 1,
  #  currency: "en",
  #  post_id: 1,
  #  content: "bar">]

  Post::TitlePrice.first
  #=> #<Post::TitlePrice:0x00...
  #  id: 1,
  #  currency: "en",
  #  post_id: 1,
  #  title: "foo">

  Post::ContentPrice.first
  #=> #<Post::ContentPrice:0x00...
  #  id: 1,
  #  currency: "en",
  #  post_id: 1,
  #  title: "bar">
=end
    class ActiveRecord::Table
      include ActiveRecord
      include Table

      class << self
        # @!group Backend Configuration
        # @option options [Symbol] association_name (:prices)
        #   Name of association method
        # @option options [Symbol] table_name Name of price table
        # @option options [Symbol] foreign_key Name of foreign key
        # @option options [Symbol] subclass_name (:Price) Name of subclass
        #   to append to model class to generate price class
        def configure(options)
          table_name = options[:model_class].table_name
          options[:table_name]  ||= "#{table_name.singularize}_prices"
          options[:foreign_key] ||= table_name.downcase.singularize.camelize.foreign_key
          if (association_name = options[:association_name]).present?
            options[:subclass_name] ||= association_name.to_s.singularize.camelize.freeze
          else
            options[:association_name] = :prices
            options[:subclass_name] ||= :Price
          end
          %i[foreign_key association_name subclass_name table_name].each { |key| options[key] = options[key].to_sym }
        end
        # @!endgroup

        # @param [String] attr Attribute name
        # @param [Symbol] _currency Currency
        # @return [Mobility::Arel::Attribute] Arel node for column on price table
        def build_node(attr, currency)
          aliased_table = model_class.const_get(subclass_name).arel_table.alias(table_alias(currency))
          Arel::Attribute.new(aliased_table, attr, currency, self)
        end

        # Joins prices using either INNER/OUTER join appropriate to the
        # query.
        # @param [ActiveRecord::Relation] relation Relation to scope
        # @param [Object] predicate Arel predicate
        # @param [Symbol] currency (Mobility.currency) Currency
        # @option [Boolean] invert
        # @return [ActiveRecord::Relation] relation Relation with joins applied (if needed)
        def apply_scope(relation, predicate, currency = Mobility.currency, invert: false)
          visitor = Visitor.new(self, currency)
          if join_type = visitor.accept(predicate)
            join_type &&= Visitor::INNER_JOIN if invert
            join_prices(relation, currency, join_type)
          else
            relation
          end
        end

        private

        def join_prices(relation, currency, join_type)
          return relation if already_joined?(relation, currency, join_type)
          m = model_class.arel_table
          t = model_class.const_get(subclass_name).arel_table.alias(table_alias(currency))
          relation.joins(m.join(t, join_type).
                         on(t[foreign_key].eq(m[:id]).
                            and(t[:currency].eq(currency))).join_sources)
        end

        def already_joined?(relation, currency, join_type)
          if join = get_join(relation, currency)
            return true if (join_type == Visitor::OUTER_JOIN) || (Visitor::INNER_JOIN === join)
            relation.joins_values = relation.joins_values - [join]
          end
          false
        end

        def get_join(relation, currency)
          relation.joins_values.find { |v| (::Arel::Nodes::Join === v) && (v.left.name == table_alias(currency).to_s) }
        end
      end

      # Internal class used to visit all nodes in a predicate clause and
      # return a single join type required for the predicate, or nil if no
      # join is required. (Similar to the KeyValue Visitor class.)
      #
      # Example:
      #
      #   class Post < ApplicationRecord
      #     extend Mobility
      #     translates :title, :content, backend: :table
      #   end
      #
      #   backend_class = Post.mobility_backend_class(:title)
      #   visitor = Mobility::Backends::ActiveRecord::Table::Visitor.new(backend_class, :en)
      #
      #   title   = backend_class.build_node("title", :en)   # arel node for title
      #   content = backend_class.build_node("content", :en) # arel node for content
      #
      #   visitor.accept(title.eq(nil).and(content.eq(nil)))
      #   #=> Arel::Nodes::OuterJoin
      #
      #   visitor.accept(title.eq("foo").and(content.eq(nil)))
      #   #=> Arel::Nodes::InnerJoin
      #
      # In the first case, both attributes are matched against nil values, so
      # we need an OUTER JOIN. In the second case, one attribute is matched
      # against a non-nil value, so we can use an INNER JOIN.
      #
      class Visitor < Arel::Visitor
        private

        def visit_Arel_Nodes_Equality(object)
          nils, nodes = [object.left, object.right].partition(&:nil?)
          if nodes.any?(&method(:visit))
            nils.empty? ? INNER_JOIN : OUTER_JOIN
          end
        end

        def visit_collection(objects)
          objects.map { |obj|
            visit(obj).tap { |visited| return visited if visited == INNER_JOIN }
          }.compact.first
        end
        alias :visit_Array :visit_collection

        # If either left or right is an OUTER JOIN (predicate with a NULL
        # argument) OR we are combining this with anything other than a
        # column on the same price table, we need to OUTER JOIN
        # here. The *only* case where we can use an INNER JOIN is when we
        # have predicates like this:
        #
        #   table.attribute1 = 'something' OR table.attribute2 = 'somethingelse'
        #
        # Here, both columns are on the same table, and both are non-nil, so
        # we can safely INNER JOIN. This is pretty subtle, think about it.
        #
        def visit_Arel_Nodes_Or(object)
          visited = [object.left, object.right].map(&method(:visit))
          if visited.all? { |v| INNER_JOIN == v }
            INNER_JOIN
          elsif visited.any?
            OUTER_JOIN
          end
        end

        def visit_Mobility_Arel_Attribute(object)
          # We compare table names here to ensure that attributes defined on
          # different backends but the same table will correctly get an OUTER
          # join when required. Use options[:table_name] here since we don't
          # know if the other backend has a +table_name+ option accessor.
          (backend_class.table_name == object.backend_class.options[:table_name]) &&
            (currency == object.currency) && OUTER_JOIN || nil
        end
      end

      setup do |_attributes, options|
        association_name = options[:association_name]
        subclass_name    = options[:subclass_name]

        price_class =
          if self.const_defined?(subclass_name, false)
            const_get(subclass_name, false)
          else
            const_set(subclass_name, Class.new(Mobility::ActiveRecord::ModelPrice))
          end

        price_class.table_name = options[:table_name]

        has_many association_name,
          class_name:  price_class.name,
          foreign_key: options[:foreign_key],
          dependent:   :destroy,
          autosave:    true,
          inverse_of:  :translated_model,
          extend:      PricesHasManyExtension

        price_class.belongs_to :translated_model,
          class_name:  name,
          foreign_key: options[:foreign_key],
          inverse_of:  association_name,
          touch: true

        before_save do
          required_attributes = self.class.mobility_attributes & price_class.attribute_names
          send(association_name).destroy_empty_prices(required_attributes)
        end

        module_name = "MobilityArTable#{association_name.to_s.camelcase}"
        unless const_defined?(module_name)
          dupable = Module.new do
            define_method :initialize_dup do |source|
              super(source)
              self.send("#{association_name}=", source.send(association_name).map(&:dup))
            end
          end
          include const_set(module_name, dupable)
        end
      end

      # Returns price for a given currency, or builds one if none is present.
      # @param [Symbol] currency
      def price_for(currency, _)
        price = prices.in_currency(currency)
        price ||= prices.build(currency: currency)
        price
      end

      module PricesHasManyExtension
        # Returns price in a given currency, or nil if none exist
        # @param [Symbol, String] currency
        def in_currency(currency)
          currency = currency.to_s
          find { |t| t.currency == currency }
        end

        # Destroys prices with all empty values
        def destroy_empty_prices(required_attributes)
          each { |t| destroy(t) if required_attributes.map(&t.method(:send)).none? }
        end
      end
    end
  end
end
