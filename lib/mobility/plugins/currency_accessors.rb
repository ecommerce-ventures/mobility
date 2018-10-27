# frozen-string-literal: true

module Mobility
  module Plugins
=begin

Defines methods for a set of currencies to access translated attributes in those
currencies directly with a method call, using a suffix including the currency:

  article.title_pt_br

If no currencies are passed as an option to the initializer,
+Mobility.available_currencies+ (i.e. `Money::Currency.all`).

@example
  class Post
    def title
      "title in #{Mobility.currency}"
    end
    include Mobility::Plugins::CurrencyAccessors.new("title", currencies: [:en, :fr])
  end

  Mobility.currency = :en
  post = Post.new
  post.title
  #=> "title in en"
  post.title_fr
  #=> "title in fr"

=end
    module CurrencyAccessors
      class << self
        # Apply currency accessors plugin to attributes.
        # @param [Attributes] attributes
        # @param [Boolean] option
        def apply(attributes, option)
          if currencies = option
            currencies = Mobility.config.default_accessor_currencies if currencies == true
            attributes.names.each do |name|
              currencies.each do |currency|
                define_reader(attributes, name, currency)
                define_writer(attributes, name, currency)
              end
            end
          end
        end

        private

        def define_reader(mod, name, currency)
          warning_message = "currency passed as option to currency accessor will be ignored"
          normalized_currency = Mobility.normalize_currency(currency)

          mod.module_eval <<-EOM, __FILE__, __LINE__ + 1
          def #{name}_#{normalized_currency}(options = {})
            return super() if options.delete(:super)
            warn "#{warning_message}" if options[:currency]
            #{name}(**options, currency: :'#{currency}')
          end

          def #{name}_#{normalized_currency}?(options = {})
            return super() if options.delete(:super)
            warn "#{warning_message}" if options[:currency]
            #{name}?(**options, currency: :'#{currency}')
          end
          EOM
        end

        def define_writer(mod, name, currency)
          warning_message = "currency passed as option to currency accessor will be ignored"
          normalized_currency = Mobility.normalize_currency(currency)

          mod.module_eval <<-EOM, __FILE__, __LINE__ + 1
          def #{name}_#{normalized_currency}=(value, options = {})
            return super(value) if options.delete(:super)
            warn "#{warning_message}" if options[:currency]
            public_send(:#{name}=, value, **options, currency: :'#{currency}')
          end
          EOM
        end
      end
    end
  end
end
