# frozen_string_literal: true

module Mobility
  module Sequel
=begin

Internal class used to force Sequel model to notice changes when mobility
setter method is called.

=end
    class ColumnChanges < Module
      # @param [Array<String>] attributes Backend attributes
      def initialize(attributes, column_affix: "%s")
        attributes.each do |attribute|
          define_method "#{attribute}=" do |value, **options|
            if !options[:super] && send(attribute) != value
              currency = options[:currency] || Mobility.currency
              column = (column_affix % attribute).to_sym
              attribute_with_currency = :"#{attribute}_#{Mobility.normalize_currency(currency)}"
              @changed_columns = changed_columns | [column, attribute.to_sym, attribute_with_currency]
            end
            super(value, **options)
          end
        end
      end
    end
  end
end
