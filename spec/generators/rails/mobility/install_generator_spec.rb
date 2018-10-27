require "spec_helper"

describe Mobility::InstallGenerator, type: :generator, orm: :active_record do
  require "generator_spec/test_case"
  include GeneratorSpec::TestCase
  include Helpers::Generators

  destination File.expand_path("../tmp", __FILE__)

  after(:all) { prepare_destination }

  describe "no options" do
    before(:all) do
      prepare_destination
      run_generator
    end

    it "generates initializer" do
      expect(destination_root).to have_structure {
        directory "config" do
          directory "initializers" do
            file "mobility.rb" do
              contains "Mobility.configure do |config|"
              contains "config.default_backend = :key_value"
              contains "config.accessor_method = :translates"
              contains "config.query_method    = :i18n"
            end
          end
        end
      }
    end

    it "generates migration for integer prices table" do
      version_string_ = version_string

      expect(destination_root).to have_structure {
        directory "db" do
          directory "migrate" do
            migration "create_integer_prices" do
              if ENV["RAILS_VERSION"] < "5.0"
                contains "class CreateIntegerPrices < ActiveRecord::Migration"
              else
                contains "class CreateIntegerPrices < ActiveRecord::Migration[#{version_string_}]"
              end
              contains "def change"
              contains "create_table :mobility_integer_prices"
              contains "t.text :value"
              contains "t.references :priceable, polymorphic: true, index: false"
              contains "add_index :mobility_integer_prices"
              contains "name: :index_mobility_integer_prices_on_keys"
              contains "name: :index_mobility_integer_prices_on_priceable_attribute"
            end
          end
        end
      }
    end
  end

  describe "--without_tables set to true" do
    before(:all) do
      prepare_destination
      run_generator %w(--without_tables)
    end

    it "does not generate migration for prices tables" do
      expect((Pathname.new(destination_root) + "db" + "migrate").exist?).to eq(false)
    end
  end
end if Mobility::Loaded::Rails
