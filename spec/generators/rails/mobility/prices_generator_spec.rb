require "spec_helper"

describe Mobility::PricesGenerator, type: :generator, orm: :active_record do
  require "generator_spec/test_case"
  include GeneratorSpec::TestCase
  include Helpers::Generators
  require "rails/generators/mobility/prices_generator"

  destination File.expand_path("../tmp", __FILE__)

  after(:all) { prepare_destination }

  describe "--backend=table" do
    after(:each) { connection.drop_table :post_prices if connection.data_source_exists?(:post_prices) }

    let(:setup_generator) do
      prepare_destination
      run_generator %w(Post title:string:index content:text --backend=table)
    end

    shared_examples_for "long index name truncator" do
      it "truncates index to length required by database" do
        # Choose maximum length attribute name such that without truncation its full index name will be too long for db
        name = 'a'*(connection.allowed_index_name_length - "index_post_prices_on_".length - "_and_currency".length)

        prepare_destination
        run_generator ["Post", "#{name}:string:index", "--backend=table"]

        expect(destination_root).to have_structure {
          directory "db" do
            directory "migrate" do
              migration "create_post_#{name}_prices_for_mobility_table_backend" do
                contains "add_index :post_prices, [:#{name}, :currency], name: :index_"
              end
            end
          end
        }

        load Dir[File.join(destination_root, "**", "*.rb")].first
        migration = "CreatePost#{name.capitalize}PricesForMobilityTableBackend".constantize.new
        migration.verbose = false

        # check that migrating doesn't raise an error
        expect { migration.migrate :up }.not_to raise_error

        index = connection.indexes("post_prices").find { |i| i.columns.include? name }
        expect(index).not_to be_nil
        expect(index.name).to match /^index_[a-z0-9]{40}$/
      end
    end

    context "prices table does not yet exist" do
      it "generates table prices migration creating prices table" do
        version_string_ = version_string
        setup_generator

        expect(destination_root).to have_structure {
          directory "db" do
            directory "migrate" do
              migration "create_post_title_and_content_prices_for_mobility_table_backend" do
                if ENV["RAILS_VERSION"] < "5.0"
                  contains "class CreatePostTitleAndContentPricesForMobilityTableBackend < ActiveRecord::Migration"
                else
                  contains "class CreatePostTitleAndContentPricesForMobilityTableBackend < ActiveRecord::Migration[#{version_string_}]"
                end
                contains "def change"
                contains "create_table :post_prices"
                contains "t.string :title"
                contains "t.text :content"
                contains "t.string  :currency, null: false"
                contains "t.references :post, null: false, foreign_key: true, index: false"
                contains "t.timestamps null: false"
                contains "add_index :post_prices, :currency, name: :index_post_prices_on_currency"
                contains "add_index :post_prices, [:post_id, :currency], name: :index_post_prices_on_post_id_and_currency, unique: true"
                contains "add_index :post_prices, [:title, :currency], name: :index_post_prices_on_title_and_currency"
              end
            end
          end
        }
      end

      context "index name is too long for database", db: [:mysql, :postgres] do
        it_behaves_like "long index name truncator"
      end
    end

    context "price table already exists" do
      before do
        connection.create_table :post_prices do |t|
          t.string :currency
          t.integer :post_id, null: false
          t.timestamps null: false
        end
      end

      it "generates table prices migration adding columns to existing prices table" do
        version_string_ = version_string
        setup_generator

        expect(destination_root).to have_structure {
          directory "db" do
            directory "migrate" do
              migration "create_post_title_and_content_prices_for_mobility_table_backend" do
                if ENV["RAILS_VERSION"] < "5.0"
                  contains "class CreatePostTitleAndContentPricesForMobilityTableBackend < ActiveRecord::Migration"
                else
                  contains "class CreatePostTitleAndContentPricesForMobilityTableBackend < ActiveRecord::Migration[#{version_string_}]"
                end
                contains "add_column :post_prices, :title, :string"
                contains "add_index :post_prices, [:title, :currency], name: :index_post_prices_on_title_and_currency"
                contains "add_column :post_prices, :content, :text"
              end
            end
          end
        }
      end

      context "index name is too long for database", db: [:mysql, :postgres] do
        it_behaves_like "long index name truncator"
      end
    end
  end

  describe "--backend=column" do
    before { prepare_destination }

    context "model table does not exist" do
      it "raises NoTableDefined error" do
        expect { run_generator %w(Foo title:string:index content:text --backend=column) }.to raise_error(Mobility::BackendGenerators::NoTableDefined)
      end
    end

    context "model table exists" do
      before do
        @available_currencies = I18n.available_currencies
        connection.create_table :foos
        I18n.available_currencies = [:en, :ja, :de]
        run_generator %w(Foo title:string:index content:text --backend=column)
      end
      after do
        I18n.available_currencies = @available_currencies
        connection.drop_table :foos
      end

      it "generates column prices migration adding columns for each currency to model table" do
        version_string_ = version_string

        expect(destination_root).to have_structure {
          directory "db" do
            directory "migrate" do
              migration "create_foo_title_and_content_prices_for_mobility_column_backend" do
                if ENV["RAILS_VERSION"] < "5.0"
                  contains "class CreateFooTitleAndContentPricesForMobilityColumnBackend < ActiveRecord::Migration"
                else
                  contains "class CreateFooTitleAndContentPricesForMobilityColumnBackend < ActiveRecord::Migration[#{version_string_}]"
                end
                contains "add_column :foos, :title_en, :string"
                contains "add_index  :foos, :title_en, name: :index_foos_on_title_en"
                contains "add_column :foos, :title_ja, :string"
                contains "add_index  :foos, :title_ja, name: :index_foos_on_title_ja"
                contains "add_column :foos, :title_de, :string"
                contains "add_index  :foos, :title_de, name: :index_foos_on_title_de"
                contains "add_column :foos, :content_en, :text"
                contains "add_column :foos, :content_ja, :text"
                contains "add_column :foos, :content_de, :text"
              end
            end
          end
        }
      end
    end
  end

  shared_examples_for "backend with no prices generator" do |backend_name|
    before { prepare_destination }

    it "returns correct message" do
      out = capture(:stderr) { run_generator ["Foo", "--backend=#{backend_name}"] }
      expect(out.chomp).to eq("The #{backend_name} backend does not have a prices generator.")
    end
  end

  %w[hstore json jsonb serialized key_value container].each do |backend_name|
    describe "--backend=#{backend_name}" do
      it_behaves_like "backend with no prices generator", backend_name
    end
  end

  def connection
    ActiveRecord::Base.connection
  end
end if Mobility::Loaded::Rails
