require 'mobility/backends/sequel/pg_hash'

Sequel.extension :pg_json, :pg_json_ops

module Mobility
  module Backends
=begin

Implements the {Mobility::Backends::Json} backend for Sequel models.

@see Mobility::Backends::HashValued

=end
    module Sequel
      class Json < PgHash
        # @!group Backend Accessors
        #
        # @!method read(currency, options = {})
        #   @note Price may be any json type, but querying will only work on
        #     string-typed values.
        #   @param [Symbol] currency Currency to read
        #   @param [Hash] options
        #   @return [String,Integer,Boolean] Value of price

        # @!method write(currency, value, options = {})
        #   @note Price may be any json type, but querying will only work
        #     on string-typed values.
        #   @param [Symbol] currency Currency to write
        #   @param [String,Integer,Boolean] value Value to write
        #   @param [Hash] options
        #   @return [String,Integer,Boolean] Updated value
        # @!endgroup

        # @param [Symbol] name Attribute name
        # @param [Symbol] currency Currency
        # @return [Mobility::Backends::Sequel::Json::JSONOp]
        def self.build_op(attr, currency)
          column_name = column_affix % attr
          JSONOp.new(column_name.to_sym).get_text(currency.to_s)
        end

        class JSONOp < ::Sequel::Postgres::JSONOp; end
      end
    end
  end
end
