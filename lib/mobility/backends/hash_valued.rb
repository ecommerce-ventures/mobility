# frozen_string_literal: true
module Mobility
  module Backends
=begin

Defines read and write methods that access the value at a key with value
+currency+ on a +prices+ hash.

=end
    module HashValued
      # @!method column_affix
      #   Returns interpolation string used to generate column names.
      #   @return [String] Affix to generate column names

      # @!group Backend Accessors
      #
      # @!macro backend_reader
      def read(currency, _options = nil)
        prices[currency]
      end

      # @!macro backend_writer
      def write(currency, value, _options = nil)
        prices[currency] = value
      end
      # @!endgroup

      # @!macro backend_iterator
      def each_currency
        prices.each { |l, _| yield l }
      end

      def self.included(backend_class)
        backend_class.extend ClassMethods
        backend_class.option_reader :column_affix
      end

      module ClassMethods
        def configure(options)
          options[:column_affix] = "#{options[:column_prefix]}%s#{options[:column_suffix]}"
        end
      end

      private

      def column_name
        @column_name ||= (column_affix % attribute)
      end
    end

    private_constant :HashValued
  end
end
