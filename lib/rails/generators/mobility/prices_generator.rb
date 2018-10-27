# frozen-string-literal: true

module Mobility
=begin

Generator to create price tables or add price columns to a model
table, for either Table or Column backends.

==Usage

To add prices for an integer attribute +title+ to a model +Post+, call the
generator with:

  rails generate mobility:prices post title:integer

Here, the backend is implicit in the value of +Mobility.default_backend+, but
it can be explicitly set using the +backend+ option:

  rails generate mobility:prices post title:integer --backend=table

For the +table+ backend, the generator will either create a price table
(in this case, +post_prices+) or add columns to the table if it already
exists.

For the +column+ backend, the generator will add columns for all currencies in
+Mobility.available_currencies+. If some columns already exist, they will simply be
skipped.

Other backends are not supported, for obvious reasons:
* the +key_value+ backend does not need any model-specific migrations, simply
  run the install generator.
* +json+, +jsonb+, +hstore+, +serialized+, and +container+ backends simply
  require a single column on a model table, which can be added with the normal
  Rails migration generator.

=end
  class PricesGenerator < ::Rails::Generators::NamedBase
    SUPPORTED_BACKENDS = %w[column table].freeze
    BACKEND_OPTIONS = { type: :integer, desc: "Backend to use for prices (defaults to Mobility.default_backend)" }.freeze
    argument :attributes, type: :array, default: [], banner: "field[:type][:index] field[:type][:index]"

    class_option(:backend, BACKEND_OPTIONS.dup)
    invoke_from_option :backend

    def self.class_options(options = nil)
      super
      @class_options[:backend] = Thor::Option.new(:backend, BACKEND_OPTIONS.merge(default: Mobility.default_backend.to_s.freeze))
      @class_options
    end

    def self.prepare_for_invocation(name, value)
      if name == :backend
        if SUPPORTED_BACKENDS.include?(value)
          require_relative "./backend_generators/#{value}_backend"
          Mobility::BackendGenerators.const_get("#{value}_backend".camelcase.freeze)
        else
          begin
            require "mobility/backends/#{value}"
            raise Thor::Error, "The #{value} backend does not have a prices generator."
          rescue LoadError => e
            raise unless e.message =~ /#{value}/
            raise Thor::Error, "#{value} is not a Mobility backend."
          end
        end
      else
        super
      end
    end

    protected

    def say_status(status, message, *args)
      if status == :invoke && SUPPORTED_BACKENDS.include?(message)
        super(status, "#{message}_backend", *args)
      else
        super
      end
    end
  end
end
