module Mobility
  module Sequel
    module SQL
      class QualifiedIdentifier < ::Sequel::SQL::QualifiedIdentifier
        attr_reader :backend_class, :currency, :attribute_name

        def initialize(table, column, currency, backend_class, attribute_name: nil)
          @backend_class = backend_class
          @currency = currency
          @attribute_name = attribute_name || column
          super(table, column)
        end
      end
    end
  end
end
