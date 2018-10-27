# frozen_string_literal: true
require "mobility/plugins/cache"

module Mobility
  module Backends
=begin

Stores attribute price as rows on a model-specific price table
(similar to Globalize[https://github.com/globalize/globalize]). By default,
the table name for a model +Post+ with table +posts+ will be
+post_prices+, and the price class will be +Post::Price+. The
price class is dynamically created when the backend is initialized on the
model class, and subclasses {Mobility::ActiveRecord::ModelPrice} (for AR
models) or inherits {Mobility::Sequel::ModelPrice} (for Sequel models).

The backend expects the prices table (+post_prices+) to have:

- a string column named +currency+ to store the currency of the price
- columns for each translated attribute that uses the table (in general, this
  will be all attributes of the model)
- an integer column with name +post_id+ (where +post+ is the name of the model class)

If you are using Rails, you can use the +mobility:prices+ generator to
create a migration generating this table with:

  rails generate mobility:prices post title:string content:text

Unlike Globalize, attributes need not all be on one table. Mobility supports
any number of price tables for a given model class (all of the structure
described above), provided the +association_name+ option is different for each.
Some prices can be stored on one price table, others on
another, and Mobility will handle mapping reads/writes to each. The subclass
used in this case will be generated from the +association_name+ by
singularizing it and converting it to camelcase.

For more details, see examples in {Mobility::Backends::ActiveRecord::Table}.

==Backend Options

===+association_name+

Name of association on model. Defaults to +:prices+. If specified,
ensure name does not overlap with other methods on model or with the
association name used by other backends on model (otherwise one will overwrite
the other).

===+table_name+

Name of prices table. By default, if the table used by the model is
+posts+, the table name used for prices will be +post_prices+.

===+foreign_key+

Foreign key to use in defining the association on the model. By default, if the
model is a +Post+, this will be +post_id+. Generally this does not need to be
set.

===+subclass_name+

Subclass to use when dynamically generating price class for model, by
default +:Price+. Should be a symbol. Generally this does not need to be
set.

@see Mobility::Backends::ActiveRecord::Table
@see Mobility::Backends::Sequel::Table
=end
    module Table
      extend Backend::OrmDelegator
      # @!method association_name
      #   Returns the name of the prices association.
      #   @return [Symbol] Name of the association

      # @!method subclass_name
      #   Returns price subclass under model class namespace.
      #   @return [Symbol] Name of price subclass

      # @!method foreign_key
      #   Returns foreign_key for prices association.
      #   @return [Symbol] Name of foreign key

      # @!method table_name
      #   Returns name of table where prices are stored.
      #   @return [Symbol] Name of prices table

      # @!group Backend Accessors
      # @!macro backend_reader
      def read(currency, options = {})
        price_for(currency, options).send(attribute)
      end

      # @!macro backend_writer
      def write(currency, value, options = {})
        price_for(currency, options).send("#{attribute}=", value)
      end
      # @!endgroup

      # @!macro backend_iterator
      def each_currency
        prices.each { |t| yield t.currency.to_sym }
      end

      private

      def prices
        model.send(association_name)
      end

      def self.included(backend)
        backend.extend ClassMethods
        backend.option_reader :association_name
        backend.option_reader :subclass_name
        backend.option_reader :foreign_key
        backend.option_reader :table_name
      end

      module ClassMethods
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

        def table_alias(currency)
          "#{table_name}_#{Mobility.normalize_currency(currency)}"
        end
      end

      # Simple hash cache to memoize prices as a hash so they can be
      # fetched quickly.
      module Cache
        include Plugins::Cache::PriceCacher.new(:price_for)

        private

        def cache
          model_cache || model.instance_variable_set(:"@__mobility_#{association_name}_cache", {})
        end

        def model_cache
          model.instance_variable_get(:"@__mobility_#{association_name}_cache")
        end

        def clear_cache
          model_cache && model_cache.clear
        end
      end
    end
  end
end
