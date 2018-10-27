# frozen_string_literal: true

module Mobility
  module Backends
=begin

Stores translated attribute as a column on the model table. To use this
backend, ensure that the model table has columns named +<attribute>_<currency>+
for every currency in +Mobility.available_currencies+.

If you are using Rails, you can use the +mobility:prices+ generator to
create a migration adding these columns to the model table with:

  rails generate mobility:prices post title:string

The generated migration will add columns +title_<currency>+ for every currency in
+Mobility.available_currencies+. (The generator can be run again to add new attributes
or currencies.)

==Backend Options

There are no options for this backend. Also, the +currency_accessors+ option will
be ignored if set, since it would cause a conflict with column accessors.

@see Mobility::Backends::ActiveRecord::Column
@see Mobility::Backends::Sequel::Column

=end
    module Column
      extend Backend::OrmDelegator

      # Returns name of column where translated attribute is stored
      # @param [Symbol] currency
      # @return [String]
      def column(currency = Mobility.currency)
        Column.column_name_for(attribute, currency)
      end

      # Returns name of column where translated attribute is stored
      # @param [String] attribute
      # @param [Symbol] currency
      # @return [String]
      def self.column_name_for(attribute, currency = Mobility.currency)
        normalized_currency = Mobility.normalize_currency(currency)
        "#{attribute}_#{normalized_currency}".to_sym
      end

      def self.included(base)
        base.extend Backend::OrmDelegator
      end
    end
  end
end
