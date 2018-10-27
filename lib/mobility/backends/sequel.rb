module Mobility
  module Backends
    module Sequel
      def self.included(backend_class)
        backend_class.include(Backend)
        backend_class.extend(ClassMethods)
      end

      module ClassMethods
        # @param [Symbol] name Attribute name
        # @param [Symbol] currency Currency
        def [](name, currency)
          build_op(name.to_s, currency)
        end

        # @param [String] _attr Attribute name
        # @param [Symbol] _currency Currency
        # @return Op for this translated attribute
        def build_op(_attr, _currency)
          raise NotImplementedError
        end

        # @param [Sequel::Dataset] dataset Dataset to prepare
        # @param [Object] predicate Predicate
        # @param [Symbol] currency Currency
        # @return [Sequel::Dataset] Prepared dataset
        def prepare_dataset(dataset, _predicate, _currency)
          dataset
        end
      end
    end
  end
end
