# frozen_string_literal: true
require "mobility/util"
require "mobility/backends/sequel"
require "mobility/backends/key_value"
require "mobility/sequel/model_price"
require "mobility/sequel/sql"

module Mobility
  module Backends
=begin

Implements the {Mobility::Backends::Table} backend for Sequel models.

=end
    class Sequel::Table
      include Sequel
      include Table

      def price_class
        self.class.price_class
      end

      class << self
        # @return [Symbol] class for prices
        def price_class
          @price_class ||= model_class.const_get(subclass_name)
        end

        # @!group Backend Configuration
        # @option options [Symbol] association_name (:prices) Name of association method
        # @option options [Symbol] table_name Name of price table
        # @option options [Symbol] foreign_key Name of foreign key
        # @option options [Symbol] subclass_name Name of subclass to append to model class to generate price class
        # @raise [CacheRequired] if cache option is false
        def configure(options)
          raise CacheRequired, "Cache required for Sequel::Table backend" if options[:cache] == false
          table_name = Util.singularize(options[:model_class].table_name)
          options[:table_name]  ||= :"#{table_name}_prices"
          options[:foreign_key] ||= Util.foreign_key(Util.camelize(table_name.downcase))
          if association_name = options[:association_name]
            options[:subclass_name] ||= Util.camelize(Util.singularize(association_name))
          else
            options[:association_name] = :prices
            options[:subclass_name] ||= :Price
          end
          %i[table_name foreign_key association_name subclass_name].each { |key| options[key] = options[key].to_sym }
        end
        # @!endgroup

        # @param [Symbol] name Attribute name
        # @param [Symbol] currency Currency
        # @return [Sequel::SQL::QualifiedIdentifier]
        def build_op(attr, currency)
          ::Mobility::Sequel::SQL::QualifiedIdentifier.new(table_alias(currency), attr, currency, self, attribute_name: attr)
        end

        # @param [Sequel::Dataset] dataset Dataset to prepare
        # @param [Object] predicate Predicate
        # @param [Symbol] currency Currency
        # @return [Sequel::Dataset] Prepared dataset
        def prepare_dataset(dataset, predicate, currency)
          join_prices(dataset, currency, visit(predicate, currency))
        end

        private

        def join_prices(dataset, currency, join_type)
          if joins = dataset.opts[:join]
            return dataset if joins.any? { |clause| clause.table_expr.alias == table_alias(currency) }
          end
          dataset.join_table(join_type,
                             price_class.table_name,
                             {
                               currency: currency.to_s,
                               foreign_key => ::Sequel[model_class.table_name][:id]
                             },
                             table_alias: table_alias(currency))
        end

        # @return [Symbol] Join type
        def visit(predicate, currency)
          case predicate
          when Array
            visit_collection(predicate, currency)
          when ::Mobility::Sequel::SQL::QualifiedIdentifier
            visit_sql_identifier(predicate, currency)
          when ::Sequel::SQL::BooleanExpression
            visit_boolean(predicate, currency)
          when ::Sequel::SQL::Expression
            visit(predicate.args, currency)
          else
            nil
          end
        end

        def visit_collection(collection, currency)
          collection.map { |obj|
            visit(obj, currency).tap do |visited|
              return visited if visited == :inner
            end
          }.compact.first
        end

        def visit_sql_identifier(identifier, currency)
          (table_alias(currency) == identifier.table) && :inner || nil
        end

        def visit_boolean(boolean, currency)
          if boolean.op == :'='
            boolean.args.any? { |op| visit(op, currency) } && :inner || nil
          elsif boolean.op == :IS
            boolean.args.any?(&:nil?) && :left_outer || nil
          elsif boolean.op == :OR
            boolean.args.any? { |op| visit(op, currency) } && :left_outer || nil
          else
            visit(boolean.args, currency)
          end
        end
      end

      setup do |attributes, options|
        association_name = options[:association_name]
        subclass_name    = options[:subclass_name]

        price_class =
          if self.const_defined?(subclass_name, false)
            const_get(subclass_name, false)
          else
            const_set(subclass_name, Class.new(::Sequel::Model(options[:table_name]))).tap do |klass|
              klass.include ::Mobility::Sequel::ModelPrice
            end
          end

        one_to_many association_name,
          class:      price_class.name,
          key:        options[:foreign_key],
          reciprocal: :translated_model

        price_class.many_to_one :translated_model,
          class:      name,
          key:        options[:foreign_key],
          reciprocal: association_name

        plugin :association_dependencies, association_name => :destroy

        callback_methods = Module.new do
          define_method :after_save do
            super()
            cache_accessor = instance_variable_get(:"@__mobility_#{association_name}_cache")
            cache_accessor.each_value do |price|
              price.id ? price.save : send("add_#{Util.singularize(association_name)}", price)
            end if cache_accessor
          end
        end
        include callback_methods

        include Mobility::Sequel::ColumnChanges.new(attributes)
      end

      def price_for(currency, _)
        price = model.send(association_name).find { |t| t.currency == currency.to_s }
        price ||= price_class.new(currency: currency)
        price
      end

      module Cache
        include Table::Cache

        private

        def prices
          (model.send(association_name) + cache.values).uniq
        end
      end

      class CacheRequired < ::StandardError; end
    end
  end
end
