# frozen-string-literal: true

module Mobility
  module Plugins
=begin

Defines +method_missing+ and +respond_to_missing?+ methods for a set of
attributes such that a method call using a currency accessor, like:

  article.title_pt_br

will return the value of +article.title+ with the currency set to +pt-BR+ around
the method call. The class is called "FallthroughAccessors" because when
included in a model class, currency-specific methods will be available even if
not explicitly defined with the +currency_accessors+ option.

This is a less efficient (but more open-ended) implementation of currency
accessors, for use in cases where the currencies to be used are not known when the
model class is generated.

@example Using fallthrough currencies on a plain old ruby class
  class Post
    def title
      "title in #{Mobility.currency}"
    end
    include Mobility::FallthroughAccessors.new("title")
  end

  Mobility.currency = :en
  post = Post.new
  post.title
  #=> "title in en"
  post.title_fr
  #=> "title in fr"

=end
    module FallthroughAccessors
      class << self
        # Apply fallthrough accessors plugin to attributes.
        # @param [Attributes] attributes
        # @param [Boolean] option
        def apply(attributes, option)
          define_method_missing(attributes, attributes.names) if option
        end

        private

        def define_method_missing(mod, *names)
          method_name_regex = /\A(#{names.join('|')})_([a-z]{3})(=?|\??)\z/.freeze

          mod.class_eval do
            define_method :method_missing do |method_name, *arguments, **options, &block|
              if method_name =~ method_name_regex
                attribute = $1.to_sym
                currency = $2
                public_send("#{attribute}#{$3}", *arguments, **options, currency: currency.to_sym)
              else
                super(method_name, *arguments, &block)
              end
            end

            define_method :respond_to_missing? do |method_name, include_private = false|
              (method_name =~ method_name_regex) || super(method_name, include_private)
            end
          end
        end
      end
    end
  end
end
