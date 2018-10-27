require 'mobility/backends/active_record/pg_hash'
require 'mobility/arel/nodes/pg_ops'

module Mobility
  module Backends
=begin

Implements the {Mobility::Backends::Hstore} backend for ActiveRecord models.

@see Mobility::Backends::HashValued

=end
    module ActiveRecord
      class Hstore < PgHash
        # @!group Backend Accessors
        # @!macro backend_reader
        # @!method read(currency, options = {})

        # @!macro backend_writer
        def write(currency, value, options = {})
          super(currency, value && value.to_s, options)
        end
        # @!endgroup

        # @param [String] attr Attribute name
        # @param [Symbol] currency Currency
        # @return [Mobility::Arel::Nodes::Hstore] Arel node for value of
        #   attribute key on hstore column
        def self.build_node(attr, currency)
          column_name = column_affix % attr
          Arel::Nodes::Hstore.new(model_class.arel_table[column_name], build_quoted(currency))
        end
      end
    end
  end
end
