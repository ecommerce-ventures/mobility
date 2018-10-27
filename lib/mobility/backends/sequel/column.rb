# frozen_string_literal: true
require "mobility/backends/sequel"
require "mobility/backends/column"

module Mobility
  module Backends
=begin

Implements the {Mobility::Backends::Column} backend for Sequel models.

=end
    class Sequel::Column
      include Sequel
      include Column

      # @!group Backend Accessors
      # @!macro backend_reader
      def read(currency, _options = nil)
        column = column(currency)
        model[column] if model.columns.include?(column)
      end

      # @!group Backend Accessors
      # @!macro backend_writer
      def write(currency, value, _options = nil)
        column = column(currency)
        model[column] = value if model.columns.include?(column)
      end

      # @!macro backend_iterator
      def each_currency
        available_currencies.each { |l| yield(l) if present?(l) }
      end

      def self.build_op(attr, currency)
        ::Sequel::SQL::QualifiedIdentifier.new(model_class.table_name,
                                               Column.column_name_for(attr, currency))
      end

      private

      def available_currencies
        @available_currencies ||= get_column_currencies
      end

      def get_column_currencies
        column_name_regex = /\A#{attribute}_([a-z]{2}(_[a-z]{2})?)\z/.freeze
        model.columns.map do |c|
          (match = c.to_s.match(column_name_regex)) && match[1].to_sym
        end.compact
      end
    end
  end
end
