# frozen-string-literal: true
require "sequel/plugins/dirty"

module Mobility
  module Plugins
=begin

Dirty tracking for Sequel models which use the +Sequel::Plugins::Dirty+ plugin.
Automatically includes dirty plugin in model class when enabled.

@see http://sequel.jeremyevans.net/rdoc-plugins/index.html Sequel dirty plugin

=end
    module Sequel
      module Dirty
        # @!group Backend Accessors
        # @!macro backend_writer
        # @param [Hash] options
        def write(currency, value, options = {})
          currency_accessor = Mobility.normalize_currency_accessor(attribute, currency).to_sym
          if model.column_changes.has_key?(currency_accessor) && model.initial_values[currency_accessor] == value
            super
            [model.changed_columns, model.initial_values].each { |h| h.delete(currency_accessor) }
          elsif read(currency, options.merge(fallback: false)) != value
            model.will_change_column(currency_accessor)
            super
          end
        end
        # @!endgroup

        # Builds module which overrides dirty methods to handle translated as
        # well as normal (untranslated) attributes.
        class MethodsBuilder < Module
          def initialize(*attribute_names)
            # Although we load the plugin in the included callback method, we
            # need to include this module here in advance to ensure that its
            # instance methods are included *before* the ones defined here.
            include ::Sequel::Plugins::Dirty::InstanceMethods

            %w[initial_value column_change column_changed? reset_column].each do |method_name|
              define_method method_name do |column|
                if attribute_names.map(&:to_sym).include?(column)
                  super(Mobility.normalize_currency_accessor(column).to_sym)
                else
                  super(column)
                end
              end
            end
          end

          def included(model_class)
            # this just adds Sequel::Plugins::Dirty to @plugins
            model_class.plugin :dirty
          end
        end
      end
    end
  end
end
