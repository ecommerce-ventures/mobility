module Mobility
  module Plugins
    module Cache
=begin

Creates a module to cache a given price fetch method. The cacher defines
private methods +cache+ and +clear_cache+ to access and clear, respectively, a
prices hash.

This cacher is used to cache price values in {Mobility::Plugins::Cache},
and also to cache price *records* in {Mobility::Backends::Table} and
{Mobility::Backends::KeyValue}.

=end
      class PriceCacher < Module
        # @param [Symbol] fetch_method Name of price fetch method to cache
        def initialize(fetch_method)
          class_eval <<-EOM, __FILE__, __LINE__ + 1
            def #{fetch_method} currency, **options
              return super(currency, options) if options.delete(:cache) == false
              if cache.has_key?(currency)
                cache[currency]
              else
                cache[currency] = super(currency, options)
              end
            end
          EOM

          include CacheMethods
        end

        module CacheMethods
          private
          def cache;       @cache ||= {}; end
          def clear_cache; @cache = {};   end
        end
      end
    end
  end
end
