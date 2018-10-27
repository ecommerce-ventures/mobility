module Mobility
  module ActiveRecord
    # @abstract Subclass and set +table_name+ to implement for a particular column type.
    class Price < ::ActiveRecord::Base
      self.abstract_class = true

      belongs_to :priceable, polymorphic: true, touch: true

      validates :key, presence: true, uniqueness: { scope: [:priceable_id, :priceable_type, :currency] }
      validates :priceable, presence: true
      validates :currency, presence: true
    end
  end
end
