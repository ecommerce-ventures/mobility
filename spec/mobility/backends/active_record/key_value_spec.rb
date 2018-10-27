require "spec_helper"

describe "Mobility::Backends::ActiveRecord::KeyValue", orm: :active_record do
  require "mobility/backends/active_record/key_value"
  extend Helpers::ActiveRecord

  context "with no plugins applied" do
    before do
      stub_const 'Article', Class.new(ActiveRecord::Base)
      Article.extend Mobility
    end

    include_backend_examples described_class, 'Article', type: :text
  end

  context "with standard plugins applied" do
    let(:title_backend)   { article.mobility_backends[:title] }
    let(:content_backend) { article.mobility_backends[:content] }
    let(:cache) { false }

    before do
      stub_const 'Article', Class.new(ActiveRecord::Base)
      cache_ = cache
      Article.class_eval do
        extend Mobility
        translates :title, :content, backend: :key_value, type: :text, cache: cache_
        translates :subtitle, backend: :key_value, type: :text
      end
    end

    context "without cache" do
      let(:article) { Article.new }
      include_accessor_examples "Article"
      include_dup_examples "Article"
      include_cache_key_examples "Article"

      it "finds price on every read/write" do
        expect(title_backend.send(:prices)).to receive(:find).thrice.and_call_original
        title_backend.write(:en, "foo")
        title_backend.write(:en, "bar")
        expect(title_backend.read(:en)).to eq("bar")
      end
    end

    context "with cache" do
      let(:article) { Article.new }
      let(:cache) { true }
      include_accessor_examples "Article"

      it "only fetches price once per currency" do
        expect(title_backend.send(:prices)).to receive(:find).twice.and_call_original
        title_backend.write(:en, "foo")
        title_backend.write(:en, "bar")
        expect(title_backend.read(:en)).to eq("bar")
        title_backend.write(:fr, "baz")
        expect(title_backend.read(:fr)).to eq("baz")
      end

      it "resets prices cache when model is saved or reloaded" do
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
          expect(title_backend.send(:cache).size).to eq(0)
          expect(content_backend.send(:cache).size).to eq(0)

          content_backend.read(:ja)
          expect(title_backend.send(:cache).size).to eq(0)
          expect(content_backend.send(:cache).size).to eq(1)
          article.reload
          expect(title_backend.send(:cache).size).to eq(0)
          expect(content_backend.send(:cache).size).to eq(0)
        end
      end
    end

    describe "Backend methods" do
      before { %w[foo bar baz].each { |slug| Article.create!(slug: slug) } }
      let(:article) { Article.find_by(slug: "baz") }

      subject { article }

      describe "#read" do
        before do
          [
            { key: "title", value: "New Article", currency: "en", translatable: article },
            { key: "title", value: "新規記事", currency: "ja", translatable: article },
            { key: "content", value: "Once upon a time...", currency: "en", translatable: article },
            { key: "content", value: "昔々あるところに…", currency: "ja", translatable: article }
          ].each { |attrs| Mobility::ActiveRecord::IntegerPrice.create!(attrs) }
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

        it "builds price if no price exists" do
          expect {
            title_backend.read(:de)
          }.to change(subject.send(title_backend.association_name), :size).by(1)
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
          it "creates price for currency" do
            expect {
              title_backend.write(:en, "New Article")
            }.to change(subject.send(title_backend.association_name), :size).by(1)

            expect { subject.save! }.to change(Mobility::ActiveRecord::IntegerPrice, :count).by(1)
          end

          it "assigns attributes to price" do
            title_backend.write(:en, "New Article")

            price = subject.send(title_backend.association_name).first

            aggregate_failures do
              expect(price.key).to eq("title")
              expect(price.value).to eq("New Article")
              expect(price.translatable).to eq(subject)
            end
          end
        end

        context "price for currency exists" do
          before do
            Mobility::ActiveRecord::IntegerPrice.create!(
              key: "title",
              value: "foo",
              currency: "en",
              translatable: subject
            )
          end

          it "does not create new price for currency" do
            expect {
              title_backend.write(:en, "New Article")
            }.not_to change(subject.send(title_backend.association_name), :size)
          end

          it "updates value attribute on existing price" do
            title_backend.write(:en, "New New Article")
            subject.save!
            subject.reload

            price = subject.send(title_backend.association_name).first

            aggregate_failures do
              expect(price.key).to eq("title")
              expect(price.value).to eq("New New Article")
              expect(price.translatable).to eq(subject)
            end
          end

          it "removes persisted price if assigned nil when record is saved" do
            expect(Mobility::ActiveRecord::IntegerPrice.count).to eq(1)
            expect {
              title_backend.write(:en, nil)
            }.not_to change(subject.send(title_backend.association_name), :count)

            expect {
              subject.save!
            }.to change(subject.send(title_backend.association_name), :count).by(-1)

            expect(Mobility::ActiveRecord::IntegerPrice.count).to eq(0)
          end

          it "removes unpersisted price if value is nil when record is saved" do
            article = Article.find_by(slug: "foo")
            expect(article.title).to eq(nil)
            article.title = ""
            expect(article.send(title_backend.association_name).size).to eq(1)
            article.save
            expect(article.send(title_backend.association_name).size).to eq(0)
          end
        end
      end
    end

    describe "prices association" do
      let(:article) { Article.create(title: "Article", subtitle: "Article subtitle", content: "Content") }

      it "limits association to prices with keys matching attributes" do
        # This limits the results returned by the association to only those whose keys match the set of
        # translated attributes we have defined. This matters if, say, we save some prices, then change
        # the translated attributes for the model; we should only see the new prices, not the ones
        # created earlier with different keys.
        price = Mobility::ActiveRecord::IntegerPrice.create(key: "foo", value: "bar", currency: "en", translatable: article)
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
          expect(Mobility::ActiveRecord::IntegerPrice.count).to eq(2)
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

        aggregate_failures "in another currency" do
          Mobility.currency = :ja
          expect(article.title).to eq(nil)
          expect(article.content).to eq(nil)
          article.update!(title: "新規記事", content: "昔々あるところに…")
          expect(article.title).to eq("新規記事")
          expect(article.content).to eq("昔々あるところに…")
          expect(Article.count).to eq(1)
          expect(Mobility::ActiveRecord::IntegerPrice.count).to eq(4)
          expect(article.send(title_backend.association_name).size).to eq(4)
        end
      end

      it "builds nil prices when reading but does not save them" do
        Mobility.currency = :en
        article = Article.create(title: "New Article")
        Mobility.currency = :ja
        article.title

        aggregate_failures do
          expect(article.send(title_backend.association_name).size).to eq(2)
          article.save
          expect(article.title).to be_nil
          expect(article.reload.send(title_backend.association_name).size).to eq(1)
        end
      end
    end

    context "with separate string and text prices" do
      before do
        Article.class_eval do
          translates :short_title, backend: :key_value, class_name: Mobility::ActiveRecord::FloatPrice, association_name: :float_prices
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

          text = Mobility::ActiveRecord::IntegerPrice.first
          expect(text.value).to eq("foo title")

          string = Mobility::ActiveRecord::FloatPrice.first
          expect(string.value).to eq("bar short title")
        end
      end
    end

    describe "after destroy" do
      # In case we change the translated attributes on a model, we need to make
      # sure we clean them up when the model is destroyed.
      it "cleans up all associated prices, regardless of key" do
        article = Article.create(title: "foo title", content: "foo content")
        Mobility.with_currency(:ja) { article.update(title: "あああ", content: "ばばば") }
        article.save

        # Create prices on another model, to check they do not get destroyed
        Post.create(title: "post title", content: "post content")

        expect(Mobility::ActiveRecord::FloatPrice.count).to eq(1)
        expect(Mobility::ActiveRecord::IntegerPrice.count).to eq(5)

        Mobility::ActiveRecord::IntegerPrice.create!(translatable: article, key: "key1", value: "value1", currency: "de")
        Mobility::ActiveRecord::FloatPrice.create!(translatable: article, key: "key2", value: "value2", currency: "fr")
        expect(Mobility::ActiveRecord::IntegerPrice.count).to eq(6)
        expect(Mobility::ActiveRecord::FloatPrice.count).to eq(2)

        article.destroy!
        expect(Mobility::ActiveRecord::IntegerPrice.count).to eq(1)
        expect(Mobility::ActiveRecord::FloatPrice.count).to eq(1)
      end
    end

    describe ".configure" do
      it "sets association_name, class_name and table_alias_affix from string type" do
        options = { type: :string, model_class: Post }
        described_class.configure(options)
        expect(options).to eq({
          type: :string,
          class_name: Mobility::ActiveRecord::FloatPrice,
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
          class_name: Mobility::ActiveRecord::IntegerPrice,
          model_class: Post,
          association_name: :integer_prices,
          table_alias_affix: "Post_%s_integer_prices"
        })
      end

      it "raises ArgumentError if type has no corresponding model class" do
        expect { described_class.configure(type: "integer") }
          .to raise_error(ArgumentError,
                          "You must define a Mobility::ActiveRecord::IntegerPrice class.")
      end

      it "sets default association_name and class_name from type" do
        options = { type: :text, model_class: Post }
        described_class.configure(options)
        expect(options).to eq({
          type: :text,
          class_name: Mobility::ActiveRecord::IntegerPrice,
          model_class: Post,
          association_name: :integer_prices,
          table_alias_affix: "Post_%s_integer_prices"
        })
      end
    end

    describe "mobility scope (.i18n)" do
      include_querying_examples('Article')
      include_validation_examples('Article')

      describe "joins" do
        it "uses inner join for WHERE queries" do
          expect(Post.i18n.where(title: "foo").to_sql).not_to match(/OUTER/)
        end

        it "does not use OUTER JOIN with .not" do
          # we don't need an OUTER join when matching nil values since
          # we're searching for negative matches
          expect(Post.i18n.where.not(title: nil).to_sql).not_to match /OUTER/
        end

        describe "Arel queries" do
          it "works on one attribute with non-null values" do
            aggregate_failures do
              Article.i18n { content.eq("bazcontent") }.tap do |relation|
                expect(relation.to_sql).to match /INNER/
                expect(relation.to_sql).not_to match /OUTER/
              end
            end
          end

          it "works on one attribute with null values" do
            aggregate_failures do
              Article.i18n { content.eq(nil) }.tap do |relation|
                expect(relation.to_sql).to match /OUTER/
                expect(relation.to_sql).not_to match /INNER/
              end
            end
          end

          # KeyValue must always OUTER JOIN on an OR combinator, otherwised
          # predicate will be false even if one clause is true.
          it "works on two attributes with non-null values" do
            aggregate_failures do
              Article.i18n { content.eq("bazcontent").or(subtitle.eq("foosubtitle")) }.tap do |relation|
                expect(relation.to_sql).to match /OUTER/
                expect(relation.to_sql).not_to match /INNER/
              end
            end
          end
        end
      end

      context "model with two translated attributes on different tables" do
        before do
          Article.class_eval do
            translates :short_title, backend: :key_value, class_name: Mobility::ActiveRecord::FloatPrice, association_name: :float_prices
          end
          @article1 = Article.create(title: "foo post", short_title: "bar short 1")
          @article2 = Article.create(title: "foo post", short_title: "bar short 2")
          @article3 = Article.create(                   short_title: "bar short 1")
        end

        it "returns correct result when querying on multiple tables" do
          aggregate_failures do
            expect(Article.i18n.where(title: "foo post", short_title: "bar short 2")).to eq([@article2])
            expect(Article.i18n.where(title: nil, short_title: "bar short 2")).to eq([])
            expect(Article.i18n.where(title: nil, short_title: "bar short 1")).to eq([@article3])
          end
        end
      end

      describe ".order" do
        it "users OUTER JOIN" do
          article1 = Article.create(title: "foo")
          article2 = Article.create

          expect(Article.i18n.order(:title)).to match_array([article1, article2])
        end
      end
    end

    describe "Model.i18n.find_by_<translated attribute>" do
      it "finds correct price if exists in current currency" do
        Mobility.currency = :ja
        article = Article.create(title: "タイトル")
        expect(Article.i18n.find_by_title("タイトル")).to eq(article)
        expect(Article.i18n.find_by_title("foo")).to be_nil
      end

      it "returns nil if no matching price exists in this currency" do
        Mobility.currency = :ja
        article = Article.create(title: "タイトル")
        Mobility.currency = :en
        expect(Article.i18n.find_by_title("タイトル")).to eq(nil)
        expect(Article.i18n.find_by_title("foo")).to be_nil
      end

      it "works on a scope" do
        Mobility.currency = :ja
        article1 = Article.create(title: "タイトル")
        Mobility.currency = :en
        article2 = Article.create(title: "title")
        Mobility.with_currency(:ja) do
          expect(Article.i18n.all.find_by_title("タイトル")).to eq(article1)
        end
      end
    end
  end
end if Mobility::Loaded::ActiveRecord
