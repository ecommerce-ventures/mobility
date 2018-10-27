require 'mobility/backends/active_record/pg_hash'
require 'mobility/arel/nodes/pg_ops'

module Mobility
  module Backends
=begin

Implements the {Mobility::Backends::Jsonb} backend for ActiveRecord models.

@see Mobility::Backends::HashValued

=end
    module ActiveRecord
      class Jsonb < PgHash
        # @!group Backend Accessors
        #
        # @!method read(currency, **options)
        #   @note Price may be any json type, but querying will only work on
        #     string-typed values.
        #   @param [Symbol] currency Currency to read
        #   @param [Hash] options
        #   @return [String,Integer,Boolean] Value of price

        # @!method write(currency, value, **options)
        #   @note Price may be any json type, but querying will only work on
        #     string-typed values.
        #   @param [Symbol] currency Currency to write
        #   @param [String,Integer,Boolean] value Value to write
        #   @param [Hash] options
        #   @return [String,Integer,Boolean] Updated value
        # @!endgroup

        # @param [String] attr Attribute name
        # @param [Symbol] currency Currency
        # @return [Mobility::Arel::Nodes::Jsonb] Arel node for value of
        #   attribute key on jsonb column
        def self.build_node(attr, currency)
          column_name = column_affix % attr
          Arel::Nodes::Jsonb.new(model_class.arel_table[column_name], build_quoted(currency))
        end
      end
    end
  end
end
