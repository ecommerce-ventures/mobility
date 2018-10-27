module Mobility
  module ActiveRecord
=begin

Subclassed dynamically to generate price class in
{Backends::ActiveRecord::Table} backend.

=end
    class ModelPrice < ::ActiveRecord::Base
      self.abstract_class = true
      validates :currency, presence: true
    end
  end
end
