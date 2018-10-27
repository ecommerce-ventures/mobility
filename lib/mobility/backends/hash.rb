module Mobility
  module Backends
=begin

Backend which stores prices in an in-memory hash.

=end
    class Hash
      include Backend

      # @!group Backend Accessors
      # @!macro backend_reader
      # @return [Object]
      def read(currency, _ = {})
        prices[currency]
      end

      # @!macro backend_writer
      # @return [Object]
      def write(currency, value, _ = {})
        prices[currency] = value
      end
      # @!endgroup

      # @!macro backend_iterator
      def each_currency
        prices.each { |l, _| yield l }
      end

      private

      def prices
        @prices ||= {}
      end
    end
  end
end
