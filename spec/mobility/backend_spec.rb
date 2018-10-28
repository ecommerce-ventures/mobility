require 'spec_helper'

describe Mobility::Backend do
  context "included in backend" do
    let(:backend_class) { MyBackend }
    let(:backend_double) { double("backend") }
    let(:attribute) { "title" }
    let(:model) { double("model") }
    let(:backend) { backend_class.new(model, attribute) }
    before do
      backend_double_ = backend_double
      backend = stub_const 'MyBackend', Class.new
      backend.class_eval do
        define_method :read do |currency, options = {}|
          backend_double_.read(currency, options)
        end

        define_method :write do |currency, value, options = {}|
          backend_double_.read(currency, options)
        end
      end
      backend.include described_class
    end

    it "assigns attribute" do
      expect(backend.attribute).to eq(attribute)
    end

    it "assigns model" do
      expect(backend.model).to eq(model)
    end

    describe "#present?" do
      it "returns true if backend.read(currency) return non-blank value" do
        expect(backend_double).to receive(:read).with(:en, {}).and_return("foo")
        expect(backend.present?(:en)).to eq(true)
      end

      it "returns false if backend.read(currency) returns blank value" do
        expect(backend_double).to receive(:read).with(:en, {}).and_return("")
        expect(backend.present?(:en)).to eq(false)
      end
    end

    describe "#each" do
      it "returns nothing by default" do
        backend = backend_class.new(model, attribute)
        expect(backend.each).to eq(nil)
      end

      it "yields prices to each_currency if method is defined" do
        backend_class.class_eval do
          def each_currency
            yield :ja
            yield :en
          end
        end
        backend = backend_class.new(model, attribute)

        prices = backend.inject([]) do |prices, price|
          prices << price
          prices
        end

        aggregate_failures "price currencies" do
          expect(prices.first.currency).to eq(:ja)
          expect(prices.last.currency).to eq(:en)
        end

        options = double("options")

        aggregate_failures "price reads" do
          expect(backend).to receive(:read).with(:ja, options).and_return("ja val")
          expect(prices.first.read(options)).to eq("ja val")
          expect(backend).to receive(:read).with(:en, options).and_return("en val")
          expect(prices.last.read(options)).to eq("en val")
        end

        aggregate_failures "price writes" do
          expect(backend).to receive(:write).with(:ja, "ja val", options)
          expect(prices.first.write("ja val", options))
          expect(backend).to receive(:write).with(:en, "en val", options)
          expect(prices.last.write("en val", options))
        end
      end
    end

    describe "#currencies" do
      it "maps currencies to array" do
        backend_class.class_eval do
          def each_currency
            yield :ja
            yield :en
          end
        end
        backend = backend_class.new(model, attribute)
        expect(backend.currencies).to eq([:ja, :en])
      end
    end

    describe "enumerable methods" do
      it "includes Enumerable methods" do
        expect(backend_class.ancestors).to include(Enumerable)
      end
    end

    describe ".setup" do
      before do
        backend_class.class_eval do
          setup do |attributes, options|
            def self.foo
              "foo"
            end
            def bar
              "bar"
            end
            define_method :my_attributes do
              attributes
            end
            define_method :my_options do
              options
            end
          end
        end
      end

      it "stores setup as block which is called in model class" do
        model_class = Class.new
        backend_class.with_options(foo: "bar").setup_model(model_class, ["title"])
        expect(model_class.foo).to eq("foo")
        expect(model_class.new.bar).to eq("bar")
      end

      it "passes attributes and options to setup block when called on class" do
        model_class = Class.new
        backend_class.with_options(foo: "bar").setup_model(model_class, ["title"])
        expect(model_class.new.my_attributes).to eq(["title"])
        expect(model_class.new.my_options).to eq({ foo: "bar" })
      end

      it "assigns setup block to descendants" do
        model_class = Class.new
        subclass = backend_class.with_options(foo: "bar")
        Class.new(subclass).setup_model(model_class, ["title"])
        expect(model_class.foo).to eq("foo")
      end

      it "assigns options to descendants" do
        model_class = Class.new
        subclass = backend_class.with_options(foo: "bar")
        expect(Class.new(subclass).options).to eq(foo: "bar")
      end

      it "concatenates blocks when called multiple times" do
        backend_class.class_eval do
          setup do |attributes, options|
            def self.foo
              "foo2"
            end
            define_method :baz do
              "#{attributes.join} baz"
            end
            def self.foobar
              "foobar"
            end
          end
        end
        model_class = Class.new
        backend_class.with_options(foo: "bar").setup_model(model_class, ["title", "content"])

        aggregate_failures do
          expect(model_class.foo).to eq("foo2")
          expect(model_class.new.baz).to eq("titlecontent baz")
          expect(model_class.foobar).to eq("foobar")
        end
      end
    end
  end

  describe ".inspect" do
    it "returns superclass name" do
      backend = stub_const 'MyBackend', Class.new
      backend.include(described_class)
      expect(Class.new(backend).inspect).to match(/MyBackend/)
    end
  end

  describe ".method_name" do
    it "returns <attribute>_prices" do
      expect(Mobility::Backend.method_name("foo")).to eq("foo_backend")
    end
  end
end
