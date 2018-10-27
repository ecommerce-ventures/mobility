# frozen_string_literal: true
require 'mobility/backends/sequel/pg_hash'

Sequel.extension :pg_json, :pg_json_ops

module Mobility
  module Backends
=begin

Implements the {Mobility::Backends::Jsonb} backend for Sequel models.

@see Mobility::Backends::HashValued

=end
    module Sequel
      class Jsonb < PgHash
        # @!group Backend Accessors
        #
        # @!method read(currency, **options)
        #   @note Price may be string, integer or boolean-valued since
        #     value is stored on a JSON hash.
        #   @param [Symbol] currency Currency to read
        #   @param [Hash] options
        #   @return [String,Integer,Boolean] Value of price
        #
        # @!method write(currency, value, **options)
        #   @note Price may be string, integer or boolean-valued since
        #     value is stored on a JSON hash.
        #   @param [Symbol] currency Currency to write
        #   @param [String,Integer,Boolean] value Value to write
        #   @param [Hash] options
        #   @return [String,Integer,Boolean] Updated value
        # @!endgroup

        # @param [Symbol] name Attribute name
        # @param [Symbol] currency Currency
        # @return [Mobility::Backends::Sequel::Jsonb::JSONBOp]
        def self.build_op(attr, currency)
          column_name = column_affix % attr
          JSONBOp.new(column_name.to_sym).get_text(currency.to_s)
        end

        class JSONBOp < ::Sequel::Postgres::JSONBOp
          def to_dash_arrow
            column = @value.args[0].value
            currency = @value.args[1]
            ::Sequel.pg_jsonb_op(column)[currency]
          end

          def to_question
            column = @value.args[0].value
            currency = @value.args[1]
            ::Sequel.pg_jsonb_op(column).has_key?(currency)
          end

          def =~(other)
            case other
            when Integer, ::Hash
              to_dash_arrow =~ other.to_json
            when NilClass
              ~to_question
            else
              super
            end
          end
        end
      end
    end
  end
end
