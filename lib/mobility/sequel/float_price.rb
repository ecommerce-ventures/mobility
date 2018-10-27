# frozen_string_literal: true
require "mobility/sequel/price"

module Mobility
  module Sequel
    class FloatPrice < ::Sequel::Model(:mobility_float_prices)
      include Price
    end
  end
end
