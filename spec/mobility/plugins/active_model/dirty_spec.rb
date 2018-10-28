require "spec_helper"

describe "Mobility::Plugins::ActiveModel::Dirty", orm: :active_record do
  require "mobility/plugins/active_model/dirty"

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
    stub_const 'Article', Class.new {
      def save
        changes_applied
      end
    }
    Article.include ActiveModel::Dirty
    Article.extend Mobility
    Article.translates :amount, backend: backend_class, dirty: true, cache: false
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
      article = Article.new
      article.amount = 100
      article.save

      aggregate_failures do
        article.amount = 200
        expect(article.changed?).to eq(true)

        article.save

        expect(article.changed?).to eq(false)
        expect(article.previous_changes).to eq({ "amount_usd" => [100, 200]})
      end
    end

    it "tracks changes in multiple currencies" do
      article = Article.new

      expect(article.amount).to eq(nil)

      aggregate_failures "change in USD currency" do
        article.amount = 300

        expect(article.changed?).to eq(true)
        expect(article.changed).to eq(["amount_usd"])
        expect(article.changes).to eq({ "amount_usd" => [nil, 300] })
      end

      aggregate_failures "change in EUR currency" do
        Mobility.currency = :eur

        article.amount = 400
        expect(article.changed?).to eq(true)
        expect(article.changed).to match_array(["amount_usd", "amount_eur"])
        expect(article.changes).to eq({ "amount_usd" => [nil, 300], "amount_eur" => [nil, 400] })
      end
    end

    it "tracks previous changes in multiple currencies" do
      article = Article.new
      article.amount_usd = "USD amount 1"
      article.amount_eur = "Titre en Francais 1"
      article.save

      article.amount = "USD amount 2"
      Mobility.currency = :eur
      article.amount = "Titre en Francais 2"

      article.save

      expect(article.previous_changes).to eq({"amount_usd" => ["USD amount 1", "USD amount 2"],
                                              "amount_eur" => ["Titre en Francais 1", "Titre en Francais 2"]})
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
        Mobility.with_currency(:eur) { article.amount = 400 }

        expect(article.changed?).to eq(true)
        expect(article.changed).to eq(["amount_eur"])
        expect(article.changes).to eq({ "amount_eur" => [nil, 400] })
      end
    end
  end

  describe "suffix methods" do
    it "defines suffix methods on translated attribute", rails_version_geq: '5.0' do
      article = Article.new
      article.amount = 100
      article.save

      article.amount = 200

      aggregate_failures do
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

        article.amount_will_change!
        expect(article.amount_changed?).to eq(true)
      end
    end

    it "returns changes on attribute for current currency", rails_version_geq: '5.0' do
      article = Article.new
      article.amount = 100
      article.save

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
      article = Article.new
      article.save

      article.amount = 100

      article.restore_amount!
      expect(article.amount).to eq(nil)
      expect(article.changes).to eq({})
    end

    it "restores attribute when passed to restore_attribute!" do
      article = Article.new
      article.save

      article.amount = 100
      article.send :restore_attribute!, :amount

      expect(article.amount).to eq(nil)
    end

    it "handles translated attributes when passed to restore_attributes" do
      article = Article.new
      article.amount = 100
      article.save

      expect(article.amount).to eq(100)

      article.amount = 200
      expect(article.amount).to eq(200)
      article.restore_attributes([:amount])
      expect(article.amount).to eq(100)
    end
  end

  describe "fallbacks compatiblity" do
    before do
      stub_const 'ArticleWithFallbacks', Class.new
      ArticleWithFallbacks.class_eval do
        include ActiveModel::Dirty
        extend Mobility
      end
      ArticleWithFallbacks.translates :amount, backend: backend_class, dirty: true, cache: false, fallbacks: { usd: 'jpy' }
    end

    it "does not compare with fallback value" do
      article = ArticleWithFallbacks.new

      aggregate_failures "before change" do
        expect(article.amount).to eq(nil)
        expect(article.changed?).to eq(false)
        expect(article.changed).to eq([])
        expect(article.changes).to eq({})
      end

      aggregate_failures "set fallback currency value" do
        Mobility.with_currency(:jpy) { article.amount = 500 }
        expect(article.amount).to eq(500)
        expect(article.changed?).to eq(true)
        expect(article.changed).to eq(["amount_jpy"])
        expect(article.changes).to eq({ "amount_jpy" => [nil, 500]})
        Mobility.with_currency(:jpy) { expect(article.amount).to eq(500) }
      end

      aggregate_failures "set value in current currency to same value" do
        article.amount = nil
        expect(article.amount).to eq(500)
        expect(article.changed?).to eq(true)
        expect(article.changed).to eq(["amount_jpy"])
        expect(article.changes).to eq({ "amount_jpy" => [nil, 500]})
      end

      aggregate_failures "set value in fallback currency to different value" do
        Mobility.with_currency(:jpy) { article.amount = 600 }
        expect(article.amount).to eq(600)
        expect(article.changed?).to eq(true)
        expect(article.changed).to eq(["amount_jpy"])
        expect(article.changes).to eq({ "amount_jpy" => [nil, 600]})
      end

      aggregate_failures "set value in current currency to different value" do
        article.amount = 1000
        expect(article.amount).to eq(1000)
        expect(article.changed?).to eq(true)
        expect(article.changed).to match_array(["amount_jpy", "amount_usd"])
        expect(article.changes).to eq({ "amount_jpy" => [nil, 600], "amount_usd" => [nil, 1000]})
      end
    end
  end
end if Mobility::Loaded::ActiveRecord
