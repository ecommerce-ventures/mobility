require "spec_helper"

describe "Mobility::Backends::Sequel::Table", orm: :sequel do
  require "mobility/backends/sequel/table"
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

    include_backend_examples backend_class_with_cache, 'Article'
  end

  context "with standard options applied" do
    let(:price_class) { Article::Price }

    before do
      stub_const 'Article', Class.new(Sequel::Model)
      Article.dataset = DB[:articles]
      Article.extend Mobility
      Article.translates :title, :content, backend: :table, cache: true
    end

    include_accessor_examples "Article"
    include_dup_examples "Article"

    it "only fetches price once per currency" do
      article = Article.new
      title_backend = article.mobility_backends[:title]
      expect(article.send(article.title_backend.association_name)).to receive(:find).twice.and_call_original
      title_backend.write(:en, "foo")
      title_backend.write(:en, "bar")
      expect(title_backend.read(:en)).to eq("bar")
      title_backend.write(:fr, "baz")
      expect(title_backend.read(:fr)).to eq("baz")
    end

    # Using Article to test separate backends with separate tables fails
    # when these specs are run together with other specs, due to code
    # assigning subclasses (Article::Price, Article::FooPrice).
    # Maybe an issue with RSpec const stubbing.
    context "attributes defined separately" do
      include_accessor_examples "MultitablePost", :title, :foo
      include_querying_examples "MultitablePost", :title, :foo
    end

    describe "Backend methods" do
      before { %w[foo bar baz].each { |slug| Article.create(slug: slug) } }
      let(:article) { Article.find(slug: "baz") }
      let(:title_backend) { article.mobility_backends[:title] }
      let(:content_backend) { article.mobility_backends[:content] }

      subject { article }

      describe "#read" do
        before do
          [
            { currency: "en", title: "New Article", content: "Once upon a time...", translated_model: article },
            { currency: "ja", title: "新規記事", content: "昔々あるところに…", translated_model: article }
          ].each { |attrs| Article::Price.create(attrs) }
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
          it "stashes price" do
            price = price_class.new(currency: :en)

            expect(price_class).to receive(:new).with(currency: :en).and_return(price)
            expect {
              title_backend.write(:en, "New Article")
            }.not_to change(price_class, :count)

            aggregate_failures do
              expect(price.currency).to eq("en")
              expect(price.title).to eq("New Article")
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
              title: "foo",
              currency: "en",
              translated_model: subject
            )
          end

          it "does not create new price for currency" do
            expect {
              title_backend.write(:en, "New Article")
              subject.save
            }.not_to change(price_class, :count)
          end

          it "updates attribute on existing price" do
            title_backend.write(:en, "New New Article")
            subject.save
            subject.reload

            price = subject.send(title_backend.association_name).first

            aggregate_failures do
              expect(price.title).to eq("New New Article")
              expect(price.currency).to eq("en")
              expect(price.translated_model).to eq(subject)
            end
          end
        end
      end
    end

    describe ".configure" do
      let(:options) { { model_class: Article } }
      it "sets association_name" do
        described_class.configure(options)
        expect(options[:association_name]).to eq(:prices)
      end

      it "sets subclass_name" do
        described_class.configure(options)
        expect(options[:subclass_name]).to eq(:Price)
      end

      it "sets table_name" do
        described_class.configure(options)
        expect(options[:table_name]).to eq(:article_prices)
      end

      it "sets foreign_key" do
        described_class.configure(options)
        expect(options[:foreign_key]).to eq(:article_id)
      end
    end

    describe "mobility scope (.i18n)" do
      include_querying_examples('Article')

      describe "joins" do
        it "uses inner join for WHERE queries if query has at least one non-null attribute" do
          expect(Article.i18n.where(title: "foo", content: nil).sql).not_to match(/OUTER/)
          expect(Article.i18n.where(title: "foo").where(content: nil).sql).not_to match(/OUTER/)
          #TODO: get this to pass
          #expect(Article.i18n.where(content: nil).where(title: "foo").sql).not_to match(/OUTER/)
          expect(Article.i18n.where(title: "foo", content: [nil, "bar"]).sql).not_to match(/OUTER/)
          expect(Article.i18n.where(title: "foo").where(content: [nil, "bar"]).sql).not_to match(/OUTER/)
          expect(Article.i18n.where(content: [nil, "bar"]).where(title: "foo").sql).not_to match(/OUTER/)
        end
      end
    end
  end
end if Mobility::Loaded::Sequel
