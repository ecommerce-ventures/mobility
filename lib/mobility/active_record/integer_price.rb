# frozen_string_literal: true
require "mobility/active_record/price"

module Mobility
  module ActiveRecord
    class IntegerPrice < Price
      self.table_name = "mobility_integer_prices"
    end
  end
end
