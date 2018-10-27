# frozen_string_literal: true
require "mobility/plugins/cache"

module Mobility
  module Backends
=begin

Stores attribute price as attribute/value pair on a shared prices
table, using a polymorphic relationship between a price class and models
using the backend. By default, two tables are assumed to be present supporting
string and text prices: a +mobility_integer_prices+ table for
integer-valued prices and a +mobility_float_prices+ table for
float-valued prices (the only difference being the column type of the
+value+ column on the table).

==Backend Options

===+type+

Currently, either +:text+ or +:string+ is supported, but any value is allowed
as long as a corresponding +class_name+ can be found (see below). Determines
which class to use for prices, which in turn determines which table to
use to store prices (by default +integer_prices+ for text type,
+float_prices+ for string type).

===+class_name+

Class to use for prices when defining association. By default,
{Mobility::ActiveRecord::IntegerPrice} or
{Mobility::ActiveRecord::FloatPrice} for ActiveRecord models (similar
for Sequel models). If string is passed in, it will be constantized to get the
class.

===+association_name+

Name of association on model. Defaults to +<type>_prices+, which will
typically be either +:integer_prices+ (if +type+ is +:text+) or
+:float_prices (if +type+ is +:string+). If specified, ensure name does
not overlap with other methods on model or with the association name used by
other backends on model (otherwise one will overwrite the other).

@see Mobility::Backends::ActiveRecord::KeyValue
@see Mobility::Backends::Sequel::KeyValue

=end
    module KeyValue
      extend Backend::OrmDelegator

      # @!method association_name
      #   Returns the name of the polymorphic association.
      #   @return [Symbol] Name of the association

      # @!method class_name
      #   Returns price class used in polymorphic association.
      #   @return [Class] Price class

      # @!group Backend Accessors
      # @!macro backend_reader
      def read(currency, options = {})
        price_for(currency, options).value
      end

      # @!macro backend_writer
      def write(currency, value, options = {})
        price_for(currency, options).value = value
      end
      # @!endgroup

      # @!macro backend_iterator
      def each_currency
        prices.each { |t| yield(t.currency.to_sym) if t.key == attribute }
      end

      private

      def prices
        model.send(association_name)
      end

      def self.included(backend_class)
        backend_class.extend ClassMethods
        backend_class.option_reader :association_name
        backend_class.option_reader :class_name
        backend_class.option_reader :table_alias_affix
      end

      module ClassMethods
        # @!group Backend Configuration
        # @option options [Symbol,String] type Column type to use
        # @option options [Symbol] associaiton_name (:<type>_prices) Name
        #   of association method, defaults to +<type>_prices+
        # @option options [Symbol] class_name Price class, defaults to
        #   +Mobility::<ORM>::<type>Price+
        # @raise [ArgumentError] if +type+ is not set, and both +class_name+
        #   and +association_name+ are also not set
        def configure(options)
          options[:type]             &&= options[:type].to_sym
          options[:association_name] &&= options[:association_name].to_sym
          options[:class_name]       &&= Util.constantize(options[:class_name])
          if !(options[:type] || (options[:class_name] && options[:association_name]))
            # TODO: Remove warning and raise ArgumentError in v1.0
            warn %{
WARNING: In previous versions, the Mobility KeyValue backend defaulted to a
text type column, but this behavior is now deprecated and will be removed in
the next release. Either explicitly specify the type by passing type: :text in
each translated model, or set a default option in your configuration.
  }
            options[:type] = :text
          end
        end

        # Apply custom processing for plugin
        # @param (see Backend::Setup#apply_plugin)
        # @return (see Backend::Setup#apply_plugin)
        def apply_plugin(name)
          if name == :cache
            include self::Cache
            true
          else
            super
          end
        end

        def table_alias(attr, currency)
          table_alias_affix % "#{attr}_#{Mobility.normalize_currency(currency)}"
        end
      end

      module Cache
        include Plugins::Cache::PriceCacher.new(:price_for)
      end
    end
  end
end
