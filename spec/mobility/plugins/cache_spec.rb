require "spec_helper"
require "mobility/plugins/cache"

describe Mobility::Plugins::Cache do
  describe "when included into a class" do
    let(:backend_class) do
      Class.new(Mobility::Backends::Null) do
        def read(*args)
          spy.read(*args)
        end

        def write(*args)
          spy.write(*args)
        end

        def spy
          @backend_double ||= RSpec::Mocks::Double.new("backend")
        end
      end
    end
    let(:cached_backend_class) { Class.new(backend_class).include(described_class) }
    let(:options) { { these: "options" } }
    let(:currency) { :gbp }

    describe "#read" do
      it "caches reads" do
        backend = cached_backend_class.new("model", "attribute")
        expect(backend.spy).to receive(:read).once.with(currency, options).and_return(100)
        2.times { expect(backend.read(currency, options)).to eq(100) }
      end

      it "does not cache reads with cache: false option" do
        backend = cached_backend_class.new("model", "attribute")
        expect(backend.spy).to receive(:read).twice.with(currency, options).and_return(100)
        2.times { expect(backend.read(currency, options.merge(cache: false))).to eq(100) }
      end

      it "does not modify options passed in" do
        backend = cached_backend_class.new("model", "attribute")
        allow(backend.spy).to receive(:read).with(currency, {}).and_return(100)
        options = { cache: false }
        backend.read(currency, options)
        expect(options).to eq({ cache: false })
      end
    end

    describe "#write" do
      it "returns value fetched from backend" do
        backend = cached_backend_class.new("model", "attribute")
        expect(backend.spy).to receive(:write).twice.with(currency, 100, options).and_return(200)
        2.times { expect(backend.write(currency, 100, options)).to eq(200) }
      end

      it "stores value fetched from backend in cache" do
        backend = cached_backend_class.new("model", "attribute")
        expect(backend.spy).to receive(:write).once.with(currency, 100, options).and_return(200)
        expect(backend.write(currency, 100, options)).to eq(200)
        expect(backend.spy).not_to receive(:read)
        expect(backend.read(currency, options)).to eq(200)
      end

      it "does not store value in cache with cache: false option" do
        backend = cached_backend_class.new("model", "attribute")
        allow(backend.spy).to receive(:write).once.with(currency, 100, options).and_return(200)
        expect(backend.write(currency, 100, options.merge(cache: false))).to eq(200)
        expect(backend.spy).to receive(:read).with(currency, options).and_return("baz")
        expect(backend.read(currency, options)).to eq("baz")
      end

      it "does not modify options passed in" do
        backend = cached_backend_class.new("model", "attribute")
        allow(backend.spy).to receive(:write).with(currency, 100, {})
        options = { cache: false }
        backend.write(currency, 100, options)
        expect(options).to eq({ cache: false })
      end
    end

    describe "resetting cache on actions" do
      shared_examples_for "cache that resets on model action" do |action, options = nil|
        it "updates backend cache on #{action}" do
          backend = @article.mobility_backends[:amount]

          aggregate_failures "reading and writing" do
            expect(backend.spy).to receive(:write).with(:usd, 100, {}).and_return(150)
            backend.write(:usd, 100)
            expect(backend.read(:usd)).to eq(150)
          end

          aggregate_failures "resetting model" do
            options ? @article.send(action, options) : @article.send(action)
            expect(backend.spy).to receive(:read).with(:usd, {}).and_return("from backend")
            expect(backend.read(:usd)).to eq("from backend")
          end
        end
      end

      shared_examples_for "cache that resets on model action with multiple backends" do |action, options = nil|
        it "updates cache on both backends on #{action}" do
          amount_backend = @article.mobility_backends[:amount]
          tax_backend = @article.mobility_backends[:tax]

          aggregate_failures "reading and writing" do
            expect(amount_backend.spy).to receive(:write).with(:usd, 100, {}).and_return(150)
            expect(tax_backend.spy).to receive(:write).with(:usd, 200, {}).and_return(250)
            amount_backend.write(:usd, 100)
            tax_backend.write(:usd, 200)
            expect(amount_backend.read(:usd)).to eq(150)
            expect(tax_backend.read(:usd)).to eq(250)
          end

          aggregate_failures "resetting model" do
            options ? @article.send(action, options) : @article.send(action)
            expect(amount_backend.spy).to receive(:read).with(:usd, {}).and_return("from amount backend")
            expect(amount_backend.read(:usd)).to eq("from amount backend")
            expect(tax_backend.spy).to receive(:read).with(:usd, {}).and_return("from tax backend")
            expect(tax_backend.read(:usd)).to eq("from tax backend")
          end
        end
      end

      context "ActiveRecord model", orm: :active_record do
        before do
          stub_const 'Article', Class.new(ActiveRecord::Base)
          Article.extend Mobility
        end

        context "with one backend" do
          before do
            Article.translates :amount, backend: backend_class, cache: true
            @article = Article.create
          end

          it_behaves_like "cache that resets on model action", :reload
          it_behaves_like "cache that resets on model action", :reload, { readonly: true, lock: true }
          it_behaves_like "cache that resets on model action", :save
        end

        context "with multiple backends" do
          before do
            other_backend = Class.new(backend_class)
            Article.translates :amount,   backend: backend_class, cache: true
            Article.translates :tax, backend: other_backend, cache: true
            @article = Article.create
          end
          it_behaves_like "cache that resets on model action with multiple backends", :reload
          it_behaves_like "cache that resets on model action with multiple backends", :reload, { readonly: true, lock: true }
          it_behaves_like "cache that resets on model action with multiple backends", :save
        end
      end

      context "Sequel model", orm: :sequel do
        before do
          stub_const 'Article', Class.new(Sequel::Model)
          Article.dataset = DB[:articles]
          Article.extend Mobility
        end

        context "with one backend" do
          before do
            Article.translates :amount, backend: backend_class, cache: true
            @article = Article.create
          end

          it_behaves_like "cache that resets on model action", :refresh
        end

        context "with multiple backends" do
          before do
            other_backend = Class.new(backend_class)
            Article.translates :amount,   backend: backend_class, cache: true
            Article.translates :tax, backend: other_backend, cache: true
            @article = Article.create
          end
          it_behaves_like "cache that resets on model action with multiple backends", :refresh
        end
      end
    end
  end

  # this is identical to apply specs for Presence, and can probably be refactored
  describe ".apply" do
    before { stub_const 'Article', Class.new }

    context "option value is truthy" do
      it "includes Cache into backend class" do
        backend_class = Class.new do
          include Mobility::Backend
        end
        attributes = instance_double(Mobility::Attributes, backend_class: backend_class, model_class: Article, names: ["amount"])
        expect(backend_class).to receive(:include).twice.with(described_class)
        described_class.apply(attributes, true)
        described_class.apply(attributes, [])
      end
    end

    context "option value is falsey" do
      it "does not include Cache into backend class" do
        attributes = instance_double(Mobility::Attributes)
        expect(attributes).not_to receive(:backend_class)
        described_class.apply(attributes, false)
        described_class.apply(attributes, nil)
      end
    end
  end
end
