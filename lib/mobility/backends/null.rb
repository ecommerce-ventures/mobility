module Mobility
  module Backends
=begin

Backend which does absolutely nothing. Mostly for testing purposes.

=end
    class Null
      include Backend

      # @!group Backend Accessors
      # @return [NilClass]
      def read(_currency, _options = nil); end

      # @return [NilClass]
      def write(_currency, _value, _options = nil); end
      # @!endgroup

      # @!group Backend Configuration
      def self.configure(_); end
      # @!endgroup
    end
  end
end
