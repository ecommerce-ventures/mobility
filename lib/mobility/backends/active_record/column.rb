# frozen_string_literal: true
require "mobility/backends/active_record"
require "mobility/backends/column"

module Mobility
  module Backends
=begin

Implements the {Mobility::Backends::Column} backend for ActiveRecord models.

You can use the +mobility:prices+ generator to create a migration adding
translatable columns to the model table with:

  rails generate mobility:prices post title:string

The generated migration will add columns +title_<currency>+ for every currency in
+Mobility.available_currencies+ (i.e. +Money::Currency.all+). (The generator
can be run again to add new attributes or currencies.)

@example
  class Post < ActiveRecord::Base
    extend Mobility
    translates :title, backend: :column
  end

  Mobility.currency = :en
  post = Post.create(title: "foo")
  post.title
  #=> "foo"
  post.title_en
  #=> "foo"
=end
    class ActiveRecord::Column
      include ActiveRecord
      include Column

      # @!group Backend Accessors
      # @!macro backend_reader
      def read(currency, _ = {})
        model.read_attribute(column(currency))
      end

      # @!macro backend_writer
      def write(currency, value, _ = {})
        model.send(:write_attribute, column(currency), value)
      end
      # @!endgroup

      # @!macro backend_iterator
      def each_currency
        available_currencies.each { |l| yield(l) if present?(l) }
      end

      # @param [String] attr Attribute name
      # @param [Symbol] currency Currency
      # @return [Arel::Attributes::Attribute] Arel node for price column
      #   on model table
      def self.build_node(attr, currency)
        model_class.arel_table[Column.column_name_for(attr, currency)]
          .extend(::Mobility::Arel::MobilityExpressions)
      end

      private

      def available_currencies
        @available_currencies ||= get_column_currencies
      end

      def get_column_currencies
        column_name_regex = /\A#{attribute}_([a-z]{3}?)\z/.freeze
        model.class.columns.map do |c|
          (match = c.name.match(column_name_regex)) && match[1].to_sym
        end.compact
      end
    end
  end
end
