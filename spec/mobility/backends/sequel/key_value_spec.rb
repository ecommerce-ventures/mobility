require "spec_helper"

describe "Mobility::Backends::Sequel::KeyValue", orm: :sequel do
  require "mobility/backends/sequel/key_value"
  extend Helpers::Sequel

  # Note: the cache is required for the Sequel Table backend, so we need to
  # apply it.
  context "with only cache plugins applied" do
    before do
      stub_const 'Article', Class.new(Sequel::Model(:articles))
      Article.extend Mobility
    end
    backend_class_with_cache = Class.new(described_class)
    backend_class_with_cache.apply_plugin(:cache)

    include_backend_examples backend_class_with_cache, 'Article', type: :text
  end

  context "with standard plugins applied" do
    let(:described_class) { Mobility::Backends::Sequel::KeyValue }
    let(:price_class) { Mobility::Sequel::IntegerPrice }
    let(:title_backend) { article.mobility_backends[:title] }
    let(:content_backend) { article.mobility_backends[:content] }

    before do
      stub_const 'Article', Class.new(::Sequel::Model)
      Article.dataset = DB[:articles]
      Article.class_eval do
        extend Mobility
        translates :title, :content, backend: :key_value, type: :text
        translates :subtitle, backend: :key_value, type: :text
      end
    end

    include_accessor_examples 'Article'
    include_dup_examples 'Article'

    describe "cache" do
      let(:article) { Article.new }

      it "only fetches price once per currency" do
        expect(article.send(title_backend.association_name)).to receive(:find).twice.and_call_original
        title_backend.write(:en, "foo")
        title_backend.write(:en, "bar")
        expect(title_backend.read(:en)).to eq("bar")
        title_backend.write(:fr, "baz")
        expect(title_backend.read(:fr)).to eq("baz")
      end

      it "resets prices cache when model is refreshed" do
        aggregate_failures "cacheing reads" do
          title_backend.read(:en)
          expect(title_backend.send(:cache).size).to eq(1)
          expect(content_backend.send(:cache).size).to eq(0)
          title_backend.read(:ja)
          expect(title_backend.send(:cache).size).to eq(2)
          expect(content_backend.send(:cache).size).to eq(0)
          content_backend.read(:fr)
          expect(title_backend.send(:cache).size).to eq(2)
          expect(content_backend.send(:cache).size).to eq(1)
        end

        aggregate_failures "resetting cache" do
          article.save
          article.refresh
          expect(title_backend.send(:cache).size).to eq(0)
          expect(content_backend.send(:cache).size).to eq(0)
        end
      end
    end

    describe "Backend methods" do
      before { %w[foo bar baz].each { |slug| Article.create(slug: slug) } }
      let(:article) { Article.find(slug: "baz") }

      subject { article }

      describe "#read" do
        before do
          [
            { key: "title", value: "New Article", currency: "en", translatable: article },
            { key: "title", value: "新規記事", currency: "ja", translatable: article },
            { key: "content", value: "Once upon a time...", currency: "en", translatable: article },
            { key: "content", value: "昔々あるところに…", currency: "ja", translatable: article }
          ].each { |attrs| price_class.create(attrs) }
        end

        it "returns attribute in currency from prices table" do
          aggregate_failures do
            expect(title_backend.read(:en)).to eq("New Article")
            expect(content_backend.read(:en)).to eq("Once upon a time...")
            expect(title_backend.read(:ja)).to eq("新規記事")
            expect(content_backend.read(:ja)).to eq("昔々あるところに…")
          end
        end

        it "returns nil if no price exists" do
          expect(title_backend.read(:de)).to eq(nil)
        end

        describe "reading back written attributes" do
          before do
            title_backend.write(:en, "Changed Article Title")
          end

          it "returns changed value" do
            expect(title_backend.read(:en)).to eq("Changed Article Title")
          end
        end
      end

      describe "#write" do
        context "no price for currency exists" do
          it "stashes price with value" do
            price = price_class.new(currency: :en, key: "title")

            expect(price_class).to receive(:new).with(currency: :en, key: "title").and_return(price)
            expect {
              title_backend.write(:en, "New Article")
            }.not_to change(price_class, :count)

            aggregate_failures do
              expect(price.currency).to eq("en")
              expect(price.key).to eq("title")
              expect(price.value).to eq("New Article")
            end
          end

          it "creates price for currency when model is saved" do
            title_backend.write(:en, "New Article")
            expect { subject.save }.to change(price_class, :count).by(1)
          end
        end

        context "price for currency exists" do
          before do
            price_class.create(
              key: "title",
              value: "foo",
              currency: "en",
              translatable: subject
            )
          end

          it "does not create new price for currency" do
            expect {
              title_backend.write(:en, "New Article")
              subject.save
            }.not_to change(price_class, :count)
          end

          it "updates value attribute on existing price" do
            title_backend.write(:en, "New New Article")
            subject.save
            subject.reload

            price = subject.send(title_backend.association_name).first

            aggregate_failures do
              expect(price.key).to eq("title")
              expect(price.value).to eq("New New Article")
              expect(price.currency).to eq("en")
              expect(price.translatable).to eq(subject)
            end
          end

          it "removes price if assigned nil when record is saved" do
            expect {
              title_backend.write(:en, nil)
            }.not_to change(price_class, :count)

            expect {
              subject.save
            }.to change(price_class, :count).by(-1)
          end
        end
      end
    end

    describe "prices association" do
      let(:article) { Article.create(title: "Article", subtitle: "Article subtitle", content: "Content") }

      it "limits association to prices with keys matching attributes" do
        price = Mobility::Sequel::IntegerPrice.create(key: "foo", value: "bar", currency: "en", translatable: article)
        article = Article.first

        aggregate_failures do
          expect(article.send(title_backend.association_name)).not_to include(price)
          expect(article.send(title_backend.association_name).count).to eq(3)
        end
      end
    end

    describe "creating a new record with prices" do
      let!(:article) { Article.create(title: "New Article", content: "Once upon a time...") }

      it "creates record and price in current currency" do
        Mobility.currency = :en

        aggregate_failures do
          expect(Article.count).to eq(1)
          expect(Mobility::Sequel::IntegerPrice.count).to eq(2)
          expect(article.send(title_backend.association_name).size).to eq(2)
          expect(article.title).to eq("New Article")
          expect(article.content).to eq("Once upon a time...")
        end
      end

      it "creates prices for other currencies" do
        Mobility.currency = :en

        aggregate_failures "in one currency" do
          expect(article.send(title_backend.association_name).count).to eq(2)
        end

        aggregate_failures "in other currency" do
          Mobility.currency = :ja
          expect(article.title).to eq(nil)
          expect(article.content).to eq(nil)
          article.update(title: "新規記事", content: "昔々あるところに…")
          expect(article.title).to eq("新規記事")
          expect(article.content).to eq("昔々あるところに…")
          expect(article.send(title_backend.association_name).count).to eq(4)
        end

        aggregate_failures "after reloading" do
          article = Article.first
          expect(article.send(title_backend.association_name).count).to eq(4)
          expect(Mobility::Sequel::IntegerPrice.count).to eq(4)
        end
      end
    end

    context "with separate string and text prices" do
      before do
        Article.class_eval do
          translates :short_title, backend: :key_value, class_name: Mobility::Sequel::FloatPrice, association_name: :float_prices
        end
      end

      it "saves prices correctly" do
        article = Article.create(title: "foo title", short_title: "bar short title")

        aggregate_failures "setting attributes" do
          expect(article.title).to eq("foo title")
          expect(article.short_title).to eq("bar short title")
        end

        aggregate_failures "after reloading" do
          article = Article.first
          expect(article.title).to eq("foo title")
          expect(article.short_title).to eq("bar short title")

          text = Mobility::Sequel::IntegerPrice.first
          expect(text.value).to eq("foo title")

          string = Mobility::Sequel::FloatPrice.first
          expect(string.value).to eq("bar short title")
        end
      end
    end

    describe "storing prices" do
      let!(:article) do
        Mobility.with_currency(:en) { article = Article.create(title: "New Article") }
      end

      it "does not save prices unless they have a value present" do
        aggregate_failures do
          Mobility.currency = :ja
          article.title
          article.save
          expect(price_class.count).to eq(1)
          expect(article.send(title_backend.association_name).count).to eq(1)
          article.title = ""
          article.save
          expect(article.title).to be_nil
          expect(price_class.count).to eq(1)
        end
      end

      it "destroys price on save if value is set to a blank value" do
        article.title = ""

        aggregate_failures do
          expect { article.valid? }.not_to change(price_class, :count)
          expect { article.save }.to change(price_class, :count).by(-1)

          expect(article.title).to eq(nil)
        end
      end

      it "does not override after_save method" do
        mod = Module.new do
          attr_reader :after_save_called
          def after_save
            super
            @after_save_called = true
          end
        end
        Article.prepend(mod)

        Mobility.currency = :en
        article = Article.create(title: "New Article")
        article.save
        expect(article.after_save_called).to eq(true)
      end

      it "resets prices if model is reloaded" do
        Mobility.currency = :ja
        article.title = "新規記事"

        article.reload
        article.save

        aggregate_failures do
          expect(price_class.count).to eq(1)
          expect(price_class.first.value).to eq("New Article")
        end
      end
    end

    describe "after destroy" do
      # In case we change the priced attributes on a model, we need to make
      # sure we clean them up when the model is destroyed.
      it "cleans up all associated prices, regardless of key" do
        article = Article.create(title: "foo title", content: "foo content")
        Mobility.with_currency(:ja) { article.update(title: "あああ", content: "ばばば") }
        article.save

        # Create prices on another model, to check they do not get destroyed
        Post.create(title: "post title", content: "post content")

        expect(Mobility::Sequel::FloatPrice.count).to eq(1)
        expect(Mobility::Sequel::IntegerPrice.count).to eq(5)

        Mobility::Sequel::IntegerPrice.create(translatable: article, key: "key1", value: "value1", currency: "de")
        Mobility::Sequel::FloatPrice.create(translatable: article, key: "key2", value: "value2", currency: "fr")
        expect(Mobility::Sequel::IntegerPrice.count).to eq(6)
        expect(Mobility::Sequel::FloatPrice.count).to eq(2)

        article.destroy
        expect(Mobility::Sequel::IntegerPrice.count).to eq(1)
        expect(Mobility::Sequel::FloatPrice.count).to eq(1)
      end

      it "only destroys prices once when cleaning up" do
        article = Article.create(title: "foo title", content: "foo content")
        # This is an ugly way to check that we are not destroying all
        # prices twice. Since the actual callback is included in a module,
        # it's hard to get at this directly.
        expect(Mobility::Sequel::IntegerPrice).to receive(:where).once.and_call_original
        expect(Mobility::Sequel::FloatPrice).to receive(:where).once.and_call_original
        article.destroy
      end
    end

    describe ".configure" do
      it "sets association_name, class_name and table_alias_affix from string type" do
        options = { type: :string, model_class: Post }
        described_class.configure(options)
        expect(options).to eq({
          type: :string,
          class_name: Mobility::Sequel::FloatPrice,
          model_class: Post,
          association_name: :float_prices,
          table_alias_affix: "Post_%s_float_prices"
        })
      end

      it "sets association_name, class_name and table_alias_affix from text type" do
        options = { type: :text, model_class: Post }
        described_class.configure(options)
        expect(options).to eq({
          type: :text,
          class_name: Mobility::Sequel::IntegerPrice,
          model_class: Post,
          association_name: :integer_prices,
          table_alias_affix: "Post_%s_integer_prices"
        })
      end

      it "raises ArgumentError if type has no corresponding model class" do
        expect { described_class.configure(type: "integer") }
          .to raise_error(ArgumentError,
                          "You must define a Mobility::Sequel::IntegerPrice class.")
      end


      it "sets default association_name, class_name and table_alias_affix from type" do
        options = { type: :text, model_class: Post }
        described_class.configure(options)
        expect(options).to eq({
          type: :text,
          class_name: Mobility::Sequel::IntegerPrice,
          model_class: Post,
          association_name: :integer_prices,
          table_alias_affix: "Post_%s_integer_prices"
        })
      end
    end

    describe "mobility dataset (.i18n)" do
      include_querying_examples 'Post'

      describe "joins" do
        it "uses inner join for WHERE queries with non-nil values" do
          expect(Post.i18n.where(title: "foo").sql).not_to match(/OUTER/)
        end
      end

      context "model with two priced attributes on different tables" do
        before do
          Article.class_eval do
            translates :short_title, backend: :key_value, class_name: Mobility::Sequel::FloatPrice, association_name: :float_prices
          end
          @article1 = Article.create(title: "foo post", short_title: "bar short 1")
          @article2 = Article.create(title: "foo post", short_title: "bar short 2")
          @article3 = Article.create(                   short_title: "bar short 1")
        end

        it "returns correct result when querying on multiple tables" do
          aggregate_failures do
            expect(Article.i18n.where(title: "foo post", short_title: "bar short 2").select_all(:articles).all).to eq([@article2])
            expect(Article.i18n.where(title: nil, short_title: "bar short 2").select_all(:articles).all).to eq([])
            expect(Article.i18n.where(title: nil, short_title: "bar short 1").select_all(:articles).all).to eq([@article3])
          end
        end
      end
    end
  end
end if Mobility::Loaded::Sequel
