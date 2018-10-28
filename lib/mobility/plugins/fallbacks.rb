# frozen_string_literal: true
require "mobility/util"

module Mobility
  module Plugins
=begin

Falls back to one or more alternative currencies in case no value is defined for a
given currency.

For +fallbacks: true+, Mobility will fall back to +Mobility.default_currency+.

If a hash is passed to the +fallbacks+ option, a new fallbacks instance will be
created for the model with the hash defining additional fallbacks. To set a
default value for this hash, use set the value of `default_options[:fallbacks]`
in your Mobility configuration (see below).

In addition, fallbacks are disabled in certain situations. To explicitly disable
fallbacks when reading and writing, you can pass the <tt>fallback: false</tt>
option to the reader method. This can be useful to determine the actual
value of the translated attribute, including a possible +nil+ value.

The other situation where fallbacks are disabled is when the currency is
specified explicitly, either by passing a `currency` option to the accessor or by
using currency or fallthrough accessors. (See example below.)

You can also pass a currency or array of currencies to the +fallback+ option to use
that currency or currencies that read, e.g. <tt>fallback: :fr</tt> would fetch the
French translation if the value in the current currency was +nil+, whereas
<tt>fallback: [:fr, :es]</tt> would try French, then Spanish if the value in
the current currency was +nil+.

@example With default fallbacks enabled (falls through to default currency)
  class Post
    extend Mobility
    translates :title, fallbacks: true
  end

  Mobility.default_currency = :en
  Mobility.currency = :en
  post = Post.new(title: "foo")

  Mobility.currency = :ja
  post.title
  #=> "foo"

  post.title = "bar"
  post.title
  #=> "bar"

@example With additional fallbacks enabled
  class Post
    extend Mobility
    translates :title, fallbacks: { :'en-US' => 'de-DE', :pt => 'de-DE' }
  end

  Mobility.currency = :'de-DE'
  post = Post.new(title: "foo")

  Mobility.currency = :'en-US'
  post.title
  #=> "foo"

  post.title = "bar"
  post.title
  #=> "bar"

@example Passing fallback option when reading value
  class Post
    extend Mobility
    translates :title, fallbacks: true
  end

  Mobility.default_currency = :en
  Mobility.currency = :en
  post = Post.new(title: "Mobility")
  Mobility.with_currency(:fr) { post.title = "Mobilité" }

  Mobility.currency = :ja
  post.title
  #=> "Mobility"
  post.title(fallback: false)
  #=> nil
  post.title(fallback: :fr)
  #=> "Mobilité"

@example Fallbacks disabled
  class Post
    extend Mobility
    translates :title, fallbacks: { :'fr' => 'en' }, currency_accessors: true
  end

  Mobility.default_currency = :en
  Mobility.currency = :en
  post = Post.new(title: "Mobility")

  Mobility.currency = :fr
  post.title
  #=> "Mobility"
  post.title(fallback: false)
  #=> nil
  post.title(currency: :fr)
  #=> nil
  post.title_fr
  #=> nil

@example Setting default fallbacks across all models
  Mobility.configure do |config|
    # ...
    config.default_options[:fallbacks] = { :'fr' => 'en' }
    # ...
  end

  class Post
    # Post will fallback from French to English by default
    translates :title, fallbacks: true
  end

=end
    class Fallbacks < Module
      # Applies fallbacks plugin to attributes. Completely disables fallbacks
      # on model if option is +false+.
      # @param [Attributes] attributes
      # @param [Boolean] option
      def self.apply(attributes, option)
        attributes.backend_class.include(new(option)) unless option == false
      end

      def initialize(fallbacks_option)
        define_read(convert_option_to_fallbacks(fallbacks_option))
      end

      private

      def define_read(fallbacks)
        define_method :read do |currency, fallback: true, **options|
          return super(currency, options) if !fallback || options[:currency]

          currencies = fallback == true ? fallbacks[currency] : [currency, *fallback]
          currencies.each do |fallback_currency|
            value = super(fallback_currency, options)
            return value if Util.present?(value)
          end

          super(currency, options)
        end
      end

      def convert_option_to_fallbacks(option)
        if option.is_a?(::Hash)
          option = option.transform_values(&:to_sym)
          ::Hash.new do |h, k|
            currencies = option[k] ? Array(option[k]) : [k]
            [k, *currencies, Mobility.default_currency].uniq
          end
        elsif option == true
          ::Hash.new { |_, k| [k, Mobility.default_currency].uniq }
        else
          ::Hash.new { [] }
        end
      end
    end
  end
end
