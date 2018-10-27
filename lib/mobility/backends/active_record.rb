module Mobility
  module Backends
    module ActiveRecord
      def self.included(backend_class)
        backend_class.include(Backend)
        backend_class.extend(ClassMethods)
      end

      module ClassMethods
        # @param [Symbol] name Attribute name
        # @param [Symbol] currency Currency
        def [](name, currency)
          build_node(name.to_s, currency)
        end

        # @param [String] _attr Attribute name
        # @param [Symbol] _currency Currency
        # @return Arel node for this translated attribute
        def build_node(_attr, _currency)
          raise NotImplementedError
        end

        # @param [ActiveRecord::Relation] relation Relation to scope
        # @param [Object] predicate Arel predicate
        # @param [Symbol] currency (Mobility.currency) Currency
        # @option [Boolean] invert
        # @return [ActiveRecord::Relation] Relation with scope added
        def apply_scope(relation, _predicate, _currency = Mobility.currency, invert: false)
          relation
        end

        private

        def build_quoted(value)
          ::Arel::Nodes.build_quoted(value)
        end
      end
    end
  end
end
