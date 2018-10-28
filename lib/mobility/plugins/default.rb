# frozen_string_literal: true

module Mobility
  module Plugins
=begin

Defines value or proc to fall through to if return value from getter would
otherwise be nil. This plugin is disabled by default but will be enabled if any
value is passed as the +default+ option key.

If default is a +Proc+, it will be called with the context of the model, and
passed arguments:
- the attribute name (a String)
- the currency (a Symbol)
- hash of options passed in to accessor
The proc can accept zero to three arguments (see examples below)

@example With default enabled (falls through to default value)
  class Post
    extend Mobility
    translates :amount, default: 100
  end

  Mobility.currency = :en
  post = Post.new(amount: "English amount")

  Mobility.currency = :de
  post.amount
  #=> 100

@example Overriding default with reader option
  class Post
    extend Mobility
    translates :amount, default: 100
  end

  Mobility.currency = :en
  post  = Post.new(amount: "English amount")

  Mobility.currency = :de
  post.amount
  #=> 100

  post.amount(default: 'bar')
  #=> 'bar'

  post.amount(default: nil)
  #=> nil

@example Using Proc as default
  class Post
    extend Mobility
    translates :amount, default: lambda { |attribute, currency| "#{attribute} in #{currency}" }
  end

  Mobility.currency = :en
  post = Post.new(amount: nil)
  post.amount
  #=> "amount in en"

  post.amount(default: lambda { self.class.name.to_s })
  #=> "Post"
=end
    module Default
      # Applies default plugin to attributes.
      # @param [Attributes] attributes
      # @param [Object] _option Ignored and plugin always applied.
      def self.apply(attributes, _option)
        attributes.backend_class.include(self)
      end

      # Generate a default value for given parameters.
      # @param [Object, Proc] default_value A default value or Proc
      # @param [Symbol] currency
      # @param [Hash] accessor_options
      # @param [String] attribute
      def self.[](default_value, currency:, accessor_options:, model:, attribute:)
        return default_value unless default_value.is_a?(Proc)
        args = [attribute, currency, accessor_options]
        args = args.first(default_value.arity) unless default_value.arity < 0
        model.instance_exec(*args, &default_value)
      end

      # @!group Backend Accessors
      # @!macro backend_reader
      # @option accessor_options [Boolean] default
      #   *false* to disable presence filter.
      def read(currency, accessor_options = {})
        default = accessor_options.has_key?(:default) ? accessor_options.delete(:default) : options[:default]
        if (value = super(currency, accessor_options)).nil?
          Default[default, currency: currency, accessor_options: accessor_options, model: model, attribute: attribute]
        else
          value
        end
      end
      # @!endgroup
    end
  end
end
