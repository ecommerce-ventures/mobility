# frozen_string_literal: true
require "mobility/active_record/price"

module Mobility
  module ActiveRecord
    class FloatPrice < Price
      self.table_name = "mobility_float_prices"
    end
  end
end
