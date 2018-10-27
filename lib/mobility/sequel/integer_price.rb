# frozen_string_literal: true
require "mobility/sequel/price"

module Mobility
  module Sequel
    class IntegerPrice < ::Sequel::Model(:mobility_integer_prices)
      include Price
    end
  end
end
