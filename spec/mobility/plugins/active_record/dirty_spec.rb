require "spec_helper"

describe "Mobility::Plugins::ActiveRecord::Dirty", orm: :active_record do
  require "mobility/plugins/active_record/dirty"

  let(:backend_class) do
    Class.new(Mobility::Backends::Null) do
      def read(currency, **options)
        values[currency]
      end

      def write(currency, value, **options)
        values[currency] = value
      end

      private

      def values
        @values ||= {}
      end
    end
  end

  before do
    stub_const 'Article', Class.new(ActiveRecord::Base)
    Article.extend Mobility
    Article.translates :amount, backend: backend_class, dirty: true, cache: false
    Article.translates :content, backend: backend_class, dirty: true, cache: false

    # ensure we include these methods as a module rather than override in class
    changes_applied_method = ::ActiveRecord::VERSION::STRING < '5.1' ? :changes_applied : :changes_internally_applied
    Article.class_eval do
      define_method changes_applied_method do
        super()
      end

      def previous_changes
        super
      end

      def clear_changes_information
        super
      end
    end
  end

  describe "tracking changes" do
    it "tracks changes in one currency" do
      Mobility.currency = :gbp
      article = Article.new

      aggregate_failures "before change" do
        expect(article.amount).to eq(nil)
        expect(article.changed?).to eq(false)
        expect(article.changed).to eq([])
        expect(article.changes).to eq({})
      end

      aggregate_failures "set same value" do
        article.amount = nil
        expect(article.amount).to eq(nil)
        expect(article.changed?).to eq(false)
        expect(article.changed).to eq([])
        expect(article.changes).to eq({})
      end

      article.amount = 100

      aggregate_failures "after change" do
        expect(article.amount).to eq(100)
        expect(article.changed?).to eq(true)
        expect(article.changed).to eq(["amount_gbp"])
        expect(article.changes).to eq({ "amount_gbp" => [nil, 100] })
      end
    end

    it "tracks previous changes in one currency" do
      article = Article.create(amount: 100)

      aggregate_failures do
        article.amount = 200
        expect(article.changed?).to eq(true)

        article.save

        expect(article.changed?).to eq(false)
        expect(article.previous_changes).to include({ "amount_usd" => [100, 200]})
      end
    end

    it "tracks previous changes in one currency in before_save hook" do
      article = Article.create(amount: 100)

      article.amount = 200
      article.save

      article.singleton_class.class_eval do
        before_save do
          @actual_previous_changes = previous_changes
        end
      end

      article.save

      expect(article.instance_variable_get(:@actual_previous_changes)).to include({ "amount_usd" => [100, 200]})
    end

    it "tracks changes in multiple currencies" do
      article = Article.new

      expect(article.amount).to eq(nil)

      aggregate_failures "change in USD currency" do
        article.amount = "USD amount"

        expect(article.changed?).to eq(true)
        expect(article.changed).to eq(["amount_usd"])
        expect(article.changes).to eq({ "amount_usd" => [nil, "USD amount"] })
      end

      aggregate_failures "change in French currency" do
        Mobility.currency = :eur

        article.amount = 300
        expect(article.changed?).to eq(true)
        expect(article.changed).to match_array(["amount_usd", "amount_eur"])
        expect(article.changes).to eq({ "amount_usd" => [nil, "USD amount"], "amount_eur" => [nil, 300] })
      end
    end

    it "tracks previous changes in multiple currencies" do
      article = Article.create(amount_usd: "USD amount 1", amount_eur: "EUR amount 1")

      article.amount = "USD amount 2"
      Mobility.currency = :eur
      article.amount = "EUR amount 2"

      article.save

      expect(article.previous_changes).to include({
        "amount_usd" => ["USD amount 1", "USD amount 2"],
        "amount_eur" => ["EUR amount 1", "EUR amount 2"]})
    end

    it "tracks forced changes" do
      article = Article.create(amount: 100)

      article.amount_will_change!

      aggregate_failures do
        expect(article.changed?).to eq(true)
        expect(article.amount_changed?).to eq(true)
        if ENV['RAILS_VERSION'].present? && ENV['RAILS_VERSION'] < '5.0'
          expect(article.content_changed?).to eq(nil)
        else
          expect(article.content_changed?).to eq(false)
        end
        expect(article.amount_change).to eq([100, 100])
        expect(article.content_change).to eq(nil)
        expect(article.previous_changes).to include({ "amount_usd" => [nil, 100]})

        article.save

        expect(article.changed?).to eq(false)
        expect(article.amount_change).to eq(nil)
        expect(article.content_change).to eq(nil)
        expect(article.previous_changes).to include({ "amount_usd" => [100, 100]})
      end
    end

    it "resets changes when currency is set to original value" do
      article = Article.new

      expect(article.changed?).to eq(false)

      aggregate_failures "after change" do
        article.amount = 100
        expect(article.changed?).to eq(true)
        expect(article.changed).to eq(["amount_usd"])
        expect(article.changes).to eq({ "amount_usd" => [nil, 100] })
      end

      aggregate_failures "after setting attribute back to original value" do
        article.amount = nil
        expect(article.changed?).to eq(false)
        expect(article.changed).to eq([])
        expect(article.changes).to eq({})
      end

      aggregate_failures "changing value in different currency" do
        Mobility.with_currency(:eur) { article.amount = 300 }

        expect(article.changed?).to eq(true)
        expect(article.changed).to eq(["amount_eur"])
        expect(article.changes).to eq({ "amount_eur" => [nil, 300] })
      end
    end
  end

  describe "suffix methods" do
    it "defines suffix methods on translated attribute" do
      article = Article.new
      article.amount = 100

      article.save
      aggregate_failures "after save" do
        expect(article.changed?).to eq(false)
        expect(article.amount_change).to eq(nil)
        expect(article.amount_was).to eq(100)

        if ENV['RAILS_VERSION'].present? && ENV['RAILS_VERSION'] < '5.0'
          expect(article.amount_changed?).to eq(nil)
        else
          expect(article.amount_previously_changed?).to eq(true)
          expect(article.amount_previous_change).to eq([nil, 100])
          expect(article.amount_changed?).to eq(false)
        end

        # AR-specific suffix methods, added in AR 5.1
        if ENV['RAILS_VERSION'].present? && ENV['RAILS_VERSION'] > '5.0'
          expect(article.saved_change_to_amount?).to eq(true)
          expect(article.saved_change_to_amount).to eq([nil, 100])
          expect(article.amount_before_last_save).to eq(nil)
          expect(article.amount_in_database).to eq(100)
        end
      end

      article.amount = 200

      aggregate_failures "changed after save" do
        expect(article.amount_changed?).to eq(true)
        expect(article.amount_change).to eq([100, 200])
        expect(article.amount_was).to eq(100)

        article.save
        if ENV['RAILS_VERSION'].present? && ENV['RAILS_VERSION'] < '5.0'
          expect(article.amount_changed?).to eq(nil)
        else
          expect(article.amount_previously_changed?).to eq(true)
          expect(article.amount_previous_change).to eq([100, 200])
          expect(article.amount_changed?).to eq(false)
        end

        # AR-specific suffix methods
        if ENV['RAILS_VERSION'].present? && ENV['RAILS_VERSION'] > '5.0'
          expect(article.saved_change_to_amount?).to eq(true)
          expect(article.saved_change_to_amount).to eq([100, 200])
          expect(article.amount_before_last_save).to eq(100)
          expect(article.will_save_change_to_amount?).to eq(false)
          expect(article.amount_change_to_be_saved).to eq(nil)
          expect(article.amount_in_database).to eq(200)
        end
      end

      aggregate_failures "force change" do
        article.amount_will_change!

        aggregate_failures "before save" do
          expect(article.amount_changed?).to eq(true)

          # AR-specific suffix methods
          if ENV['RAILS_VERSION'].present? && ENV['RAILS_VERSION'] > '5.0'
            expect(article.saved_change_to_amount?).to eq(true)
            expect(article.saved_change_to_amount).to eq([100, 200])
            expect(article.amount_before_last_save).to eq(100)
            expect(article.will_save_change_to_amount?).to eq(true)
            expect(article.amount_change_to_be_saved).to eq([200, 200])
            expect(article.amount_in_database).to eq(200)
          end
        end

        article.save!

        aggregate_failures "after save" do
          if ENV['RAILS_VERSION'].present? && ENV['RAILS_VERSION'] < '5.0'
            expect(article.amount_changed?).to eq(nil)
          else
            expect(article.amount_changed?).to eq(false)
          end

          # AR-specific suffix methods
          if ENV['RAILS_VERSION'].present? && ENV['RAILS_VERSION'] > '5.0'
            expect(article.saved_change_to_amount?).to eq(true)
            expect(article.saved_change_to_amount).to eq([200, 200])
            expect(article.amount_before_last_save).to eq(200)
            expect(article.will_save_change_to_amount?).to eq(false)
            expect(article.amount_change_to_be_saved).to eq(nil)
            expect(article.amount_in_database).to eq(200)
          end
        end
      end
    end

    it "returns changes on attribute for current currency" do
      article = Article.create(amount: 100)

      article.amount = 200

      aggregate_failures do
        expect(article.amount_changed?).to eq(true)
        expect(article.amount_change).to eq([100, 200])
        expect(article.amount_was).to eq(100)

        Mobility.currency = :eur
        if ENV['RAILS_VERSION'].present? && ENV['RAILS_VERSION'] < '5.0'
          expect(article.amount_changed?).to eq(nil)
        else
          expect(article.amount_changed?).to eq(false)
        end
        expect(article.amount_change).to eq(nil)
        expect(article.amount_was).to eq(nil)
      end
    end
  end

  describe "restoring attributes" do
    it "defines restore_<attribute>! for translated attributes" do
      Mobility.currency = :gbp
      article = Article.create

      article.amount = 100

      article.restore_amount!
      expect(article.amount).to eq(nil)
      expect(article.changes).to eq({})
    end

    it "restores attribute when passed to restore_attribute!" do
      article = Article.create

      article.amount = 100
      article.send :restore_attribute!, :amount

      expect(article.amount).to eq(nil)
    end

    it "handles translated attributes when passed to restore_attributes" do
      article = Article.create(amount: 100)

      expect(article.amount).to eq(100)

      article.amount = 200
      expect(article.amount).to eq(200)
      article.restore_attributes([:amount])
      expect(article.amount).to eq(100)
    end
  end

  describe "resetting original values hash on actions" do
    shared_examples_for "resets on model action" do |action|
      it "resets changes when model on #{action}" do
        article = Article.create

        aggregate_failures do
          article.amount = 100
          expect(article.changes).to eq({ "amount_usd" => [nil, 100] })

          article.send(action)

          # bypass the dirty module and set the variable directly
          article.mobility_backends[:amount].instance_variable_set(:@values, { :usd => 200 })

          expect(article.amount).to eq(200)
          expect(article.changes).to eq({})

          article.amount = nil
          expect(article.changes).to eq({ "amount_usd" => [200, nil]})
        end
      end
    end

    it_behaves_like "resets on model action", :save
    it_behaves_like "resets on model action", :reload
  end

  if ENV['RAILS_VERSION'].present? && ENV['RAILS_VERSION'] > '5.0'
    describe "#saved_changes" do
      it "includes translated attributes" do
        article = Article.create

        article.amount = "foo en"
        Mobility.with_currency(:jpy) { article.amount = "foo ja" }
        article.save

        aggregate_failures do
          saved_changes = article.saved_changes
          expect(saved_changes).to include("amount_usd", "amount_jpy")
          expect(saved_changes["amount_usd"]).to eq([nil, "foo en"])
          expect(saved_changes["amount_jpy"]).to eq([nil, "foo ja"])
        end
      end
    end
  end

  # Regression test for https://github.com/shioyama/mobility/issues/149
  describe "#_read_attribute" do
    it "is public" do
      article = Article.create
      expect { article._read_attribute(100) }.not_to raise_error
    end
  end
end if Mobility::Loaded::ActiveRecord
