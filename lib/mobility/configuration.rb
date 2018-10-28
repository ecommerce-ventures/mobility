# frozen_string_literal: true

module Mobility
=begin

Stores shared Mobility configuration referenced by all backends.

=end
  class Configuration
    RESERVED_OPTION_KEYS = %i[backend model_class].freeze

    # Alias for mobility_accessor (defaults to +translates+)
    # @return [Symbol]
    attr_accessor :accessor_method

    # Name of query scope/dataset method (defaults to +i18n+)
    # @return [Symbol]
    attr_accessor :query_method

    # Default set of options. These will be merged with any backend options
    # when defining translated attributes (with +translates+). Default options
    # may not include the keys 'backend' or 'model_class'.
    # @return [Hash]
    attr_reader :default_options

    # Default currency.
    # @return [Symbol]
    attr_accessor :default_currency

    # @deprecated The default_options= setter has been deprecated. Set each
    #   option on the default_options hash instead.
    def default_options=(options)
      warn %{
WARNING: The default_options= setter has been deprecated.
Set each option on the default_options hash instead, like this:

  config.default_options[:dirty] = true
}
      if (keys = options.keys & RESERVED_OPTION_KEYS).present?
        raise ReservedOptionKey,
          "Default options may not contain the following reserved keys: #{keys.join(', ')}"
      else
        @default_options = options
      end
    end

    # Plugins to apply. Order of plugins is important, as this becomes the
    # order in which plugins modules are included into the backend class or
    # attributes instance.
    # @return [Array<Symbol>]
    attr_accessor :plugins

    # Default backend to use (can be symbol or actual backend class)
    # @return [Symbol,Class]
    attr_accessor :default_backend

    # Returns set of default accessor currencies to use (defaults to
    # +Mobility.available_currencies+)
    # @return [Array<Symbol>]
    def default_accessor_currencies
      if @default_accessor_currencies.is_a?(Proc)
        @default_accessor_currencies.call
      else
        @default_accessor_currencies
      end
    end
    attr_writer :default_accessor_currencies

    def initialize
      @accessor_method = :translates
      @query_method = :i18n
      @default_currency = :usd
      @default_accessor_currencies = lambda { Mobility.available_currencies }
      @default_options = Options[{
        cache:     true,
        presence:  true,
        query:     true,
        # A nil key here includes the plugin so it can be optionally turned on
        # when reading an attribute using accessor options.
        fallbacks: nil
      }]
      @plugins = %i[
        query
        cache
        dirty
        fallbacks
        presence
        default
        attribute_methods
        fallthrough_accessors
        currency_accessors
      ]
    end

    class ReservedOptionKey < Exception; end

    class Options < ::Hash
      def []=(key, _)
        if RESERVED_OPTION_KEYS.include?(key)
          raise Configuration::ReservedOptionKey, "Default options may not contain the following reserved key: #{key}"
        end
        super
      end
    end
  end
end
