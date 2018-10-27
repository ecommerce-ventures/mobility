require 'mobility/backends/sequel/pg_hash'

Sequel.extension :pg_hstore, :pg_hstore_ops

module Mobility
  module Backends
=begin

Implements the {Mobility::Backends::Hstore} backend for Sequel models.

@see Mobility::Backends::HashValued

=end
    module Sequel
      class Hstore < PgHash
        # @!group Backend Accessors
        # @!macro backend_reader
        # @!method read(currency, options = {})

        # @!group Backend Accessors
        # @!macro backend_writer
        def write(currency, value, options = {})
          super(currency, value && value.to_s, options)
        end
        # @!endgroup

        # @param [Symbol] name Attribute name
        # @param [Symbol] currency Currency
        # @return [Mobility::Backends::Sequel::Hstore::HStoreOp]
        def self.build_op(attr, currency)
          column_name = column_affix % attr
          HStoreOp.new(column_name.to_sym)[currency.to_s]
        end

        class HStoreOp < ::Sequel::Postgres::HStoreOp; end
      end
    end
  end
end
