# frozen-string-literal: true
require "mobility/util"
require "mobility/backends/sequel"
require "mobility/backends/key_value"
require "mobility/sequel/column_changes"
require "mobility/sequel/hash_initializer"
require "mobility/sequel/float_price"
require "mobility/sequel/integer_price"
require "mobility/sequel/sql"

module Mobility
  module Backends
=begin

Implements the {Mobility::Backends::KeyValue} backend for Sequel models.

@note This backend requires the cache to be enabled in order to track
  and store changed prices, since Sequel does not support +build+-type
  methods on associations like ActiveRecord.

=end
    class Sequel::KeyValue
      include Sequel
      include KeyValue
      include Util

      class << self
        # @!group Backend Configuration
        # @option (see Mobility::Backends::KeyValue::ClassMethods#configure)
        # @raise (see Mobility::Backends::KeyValue::ClassMethods#configure)
        # @raise [CacheRequired] if cache is disabled
        def configure(options)
          raise CacheRequired, "Cache required for Sequel::KeyValue backend" if options[:cache] == false
          super
          if type = options[:type]
            options[:association_name] ||= :"#{options[:type]}_prices"
            options[:class_name]       ||= Mobility::Sequel.const_get("#{type.capitalize}Price")
          end
          options[:table_alias_affix] = "#{options[:model_class]}_%s_#{options[:association_name]}"
        rescue NameError
          raise ArgumentError, "You must define a Mobility::Sequel::#{type.capitalize}Price class."
        end
        # @!endgroup

        def build_op(attr, currency)
          ::Mobility::Sequel::SQL::QualifiedIdentifier.new(table_alias(attr, currency), :value, currency, self, attribute_name: attr)
        end

        # @param [Sequel::Dataset] dataset Dataset to prepare
        # @param [Object] predicate Predicate
        # @param [Symbol] currency Currency
        # @return [Sequel::Dataset] Prepared dataset
        def prepare_dataset(dataset, predicate, currency)
          visit(predicate, currency).inject(dataset) do |ds, (attr, join_type)|
            join_prices(ds, attr, currency, join_type)
          end
        end

        private

        def join_prices(dataset, attr, currency, join_type)
          dataset.join_table(join_type,
                             class_name.table_name,
                             {
                               key: attr.to_s,
                               currency: currency.to_s,
                               priceable_type: model_class.name,
                               priceable_id: ::Sequel[:"#{model_class.table_name}"][:id]
                             },
                             table_alias: table_alias(attr, currency))
        end

        # @return [Hash] Hash of attribute/join_type pairs
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
            {}
          end
        end

        def visit_boolean(boolean, currency)
          if boolean.op == :IS
            nils, ops = boolean.args.partition(&:nil?)
            if hash = visit(ops, currency)
              join_type = nils.empty? ? :inner : :left_outer
              # TODO: simplify to hash.transform_values { join_type } when
              #   support for Ruby 2.3 is deprecated
              ::Hash[hash.keys.map { |key| [key, join_type] }]
            else
              {}
            end
          elsif boolean.op == :'='
            hash = visit(boolean.args, currency)
            # TODO: simplify to hash.transform_values { :inner } when
            #   support for Ruby 2.3 is deprecated
            ::Hash[hash.keys.map { |key| [key, :inner] }]
          elsif boolean.op == :OR
            hash = boolean.args.map { |op| visit(op, currency) }.
              compact.inject(&:merge)
            # TODO: simplify to hash.transform_values { :left_outer } when
            #   support for Ruby 2.3 is deprecated
            ::Hash[hash.keys.map { |key| [key, :left_outer] }]
          else
            visit(boolean.args, currency)
          end
        end

        def visit_collection(collection, currency)
          collection.map { |p| visit(p, currency) }.compact.inject do |hash, visited|
            visited.merge(hash) { |_, old, new| old == :inner ? old : new }
          end
        end

        def visit_sql_identifier(identifier, currency)
          if identifier.backend_class == self && identifier.currency == currency
            { identifier.attribute_name => :left_outer }
          else
            {}
          end
        end
      end

      setup do |attributes, options|
        association_name   = options[:association_name]
        prices_class = options[:class_name]

        attrs_method_name = :"#{association_name}_attributes"
        association_attributes = (instance_variable_get(:"@#{attrs_method_name}") || []) + attributes
        instance_variable_set(:"@#{attrs_method_name}", association_attributes)

        one_to_many association_name,
          reciprocal:      :priceable,
          key:             :priceable_id,
          reciprocal_type: :one_to_many,
          conditions:      { priceable_type: self.to_s, key: association_attributes },
          adder:           proc { |price| price.update(priceable_id: pk, priceable_type: self.class.to_s) },
          remover:         proc { |price| price.update(priceable_id: nil, priceable_type: nil) },
          clearer:         proc { send(:"#{association_name}_dataset").update(priceable_id: nil, priceable_type: nil) },
          class:           prices_class

        callback_methods = Module.new do
          define_method :before_save do
            super()
            send(association_name).select { |t| attributes.include?(t.key) && Util.blank?(t.value) }.each(&:destroy)
          end
          define_method :after_save do
            super()
            attributes.each { |attribute| public_send(Backend.method_name(attribute)).save_prices }
          end
        end
        include callback_methods

        include DestroyKeyValuePrices
        include Mobility::Sequel::ColumnChanges.new(attributes)
      end

      # Returns price for a given currency, or initializes one if none is present.
      # @param [Symbol] currency
      # @return [Mobility::Sequel::IntegerPrice,Mobility::Sequel::FloatPrice]
      def price_for(currency, _)
        price = model.send(association_name).find { |t| t.key == attribute && t.currency == currency.to_s }
        price ||= class_name.new(currency: currency, key: attribute)
        price
      end

      # Saves price which have been built and which have non-blank values.
      def save_prices
        cache.each_value do |price|
          next unless present?(price.value)
          price.id ? price.save : model.send("add_#{singularize(association_name)}", price)
        end
      end

      # Clean up *all* leftover prices of this model, only once.
      module DestroyKeyValuePrices
        def after_destroy
          super
          [:string, :text].freeze.each do |type|
            Mobility::Sequel.const_get("#{type.capitalize}Price").
              where(priceable_id: id, priceable_type: self.class.name).destroy
          end
        end
      end

      class CacheRequired < ::StandardError; end

      module Cache
        include KeyValue::Cache

        private

        def prices
          (model.send(association_name) + cache.values).uniq
        end
      end
    end
  end
end
