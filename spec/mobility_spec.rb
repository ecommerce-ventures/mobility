require 'spec_helper'

describe Mobility do
  it 'has a version number' do
    expect(described_class::VERSION).not_to be nil
  end

  describe "including Mobility in class" do
    let!(:model) do
      model = stub_const 'MyModel', Class.new
      model.class_eval do
        def attributes
          { "foo" => "bar" }
        end
      end
      model
    end

    it "aliases mobility_accessor if Mobility.config.accessor_method is set" do
      expect(described_class.config).to receive(:accessor_method).and_return(:foo_translates)
      model.extend described_class
      expect { described_class.translates }.to raise_error(NoMethodError)
      model.foo_translates :title, backend: :null, foo: :bar
      expect(model.new.methods).to include :title
      expect(model.new.methods).to include :title=
    end

    it "does not alias mobility_accessor to anything if Mobility.config.accessor_method is falsy" do
      expect(described_class.config).to receive(:accessor_method).and_return(nil)
      model.extend described_class
      expect { described_class.translates }.to raise_error(NoMethodError)
    end

    context "with translated attributes" do
      it "includes backend module into model class" do
        expect(described_class::Attributes).to receive(:new).
          with(:title, { method: :accessor, backend: :null, foo: :bar }).
          and_call_original
        model.extend described_class
        model.translates :title, backend: :null, foo: :bar
      end

      it "defines translated_attribute_names" do
        model.extend described_class
        model.translates :title, backend: :null
        expect(MyModel.translated_attribute_names).to eq(["title"])
      end

      context "model subclass" do
        it "inherits translated_attribute_names" do
          model.extend described_class
          model.translates :title, backend: :null
          subclass = Class.new(model)
          expect(subclass.translated_attribute_names).to eq(["title"])
        end

        it "defines new translated attributes independently of superclass" do
          model.extend described_class
          model.translates :title, backend: :null
          subclass = Class.new(model)
          subclass.translates :content, backend: :null

          expect(model.translated_attribute_names).to eq(["title"])
          expect(subclass.translated_attribute_names).to match_array(["title", "content"])
        end
      end
    end
  end

  describe '.with_currency' do
    def perform_with_currency(currency)
      Thread.new do
        described_class.with_currency(currency) do
          Thread.pass
          expect(currency).to eq(described_class.currency)
        end
      end
    end

    it 'sets currency in a single thread' do
      perform_with_currency(:en).join
    end

    it 'sets independent currencies in multiple threads' do
      threads = []
      threads << perform_with_currency(:en)
      threads << perform_with_currency(:fr)
      threads << perform_with_currency(:de)
      threads << perform_with_currency(:cz)
      threads << perform_with_currency(:pl)

      threads.each(&:join)
    end

    it "returns result" do
      expect(described_class.with_currency(:ja) { |currency| "returned-#{currency}" }).to eq("returned-ja")
    end

    context "something blows up" do
      it "sets currency back" do
        described_class.with_currency(:ja) { raise StandardError } rescue StandardError
        expect(described_class.currency).to eq(:en)
      end
    end
  end

  describe ".currency" do
    it "returns currency if set" do
      described_class.currency = :de
      expect(described_class.currency).to eq(:de)
    end

    it "returns I18n.currency otherwise" do
      described_class.currency = nil
      I18n.currency = :de
      expect(described_class.currency).to eq(:de)
    end
  end

  describe '.currency=' do
    it "sets currency for currency in I18n.available_currencies" do
      described_class.currency = :fr
      expect(described_class.currency).to eq(:fr)
    end

    it "converts string to symbol" do
      described_class.currency = "fr"
      expect(described_class.currency).to eq(:fr)
    end

    it "raises Mobility::InvalidCurrency for currency not in I18n.available_currencies" do
      expect {
        described_class.currency = :es
      }.to raise_error(described_class::InvalidCurrency)
    end

    context "I18n.enforce_available_currencies = false" do
      around do |example|
        I18n.enforce_available_currencies = false
        example.run
        I18n.enforce_available_currencies = true
      end

      it "does not raise Mobility::InvalidCurrency for currency not in I18n.available_currencies" do
        expect {
          described_class.currency = :es
        }.not_to raise_error
      end
    end
  end

  describe ".available_currencies" do
    around do |example|
      @available_currencies = I18n.available_currencies
      I18n.available_currencies = [:en, :pt]
      example.run
      I18n.available_currencies = @available_currencies
    end

    it "defaults to I18n.available_currencies" do
      expect(described_class.available_currencies).to eq([:en, :pt])
    end

    # @note Required since model may be loaded in initializer before Rails has
    #   updated I18n.available_currencies.
    it "uses Rails i18n currencies if Rails application is loaded" do
      allow(Rails).to receive_message_chain(:application, :config, :i18n, :available_currencies).
        and_return([:ru, :cn])
      expect(described_class.available_currencies).to eq([:ru, :cn])
    end if Mobility::Loaded::Rails
  end

  describe '.normalize_currency' do
    it "normalizes currency to lowercase string underscores" do
      expect(described_class.normalize_currency(:"pt-BR")).to eq("pt_br")
    end

    it "normalizes current currency if passed no argument" do
      described_class.with_currency(:"pt-BR") do
        aggregate_failures do
          expect(described_class.normalize_currency).to eq("pt_br")
          expect(described_class.normalized_currency).to eq("pt_br")
        end
      end
    end

    it "normalizes currencies with multiple dashes" do
      expect(described_class.normalize_currency(:"foo-bar-baz")).to eq("foo_bar_baz")
    end
  end

  describe '.normalize_currency_accessor' do
    it "normalizes accessor to use lowercase currency with underscores" do
      expect(described_class.normalize_currency_accessor(:foo, :"pt-BR")).to eq("foo_pt_br")
    end

    it "defaults currency to Mobility.currency" do
      described_class.with_currency(:fr) do
        expect(described_class.normalize_currency_accessor(:foo)).to eq("foo_fr")
      end
    end

    it "raises ArgumentError for invalid attribute or currency" do
      expect { described_class.normalize_currency_accessor(:"a-*-b") }.
        to raise_error(ArgumentError, "\"a-*-b_en\" is not a valid accessor")
    end
  end

  describe '.config' do
    it 'initializes a new configuration' do
      expect(described_class.config).to be_a(described_class::Configuration)
    end

    it 'memoizes configuration' do
      expect(described_class.config).to be(described_class.config)
    end
  end

  describe ".configure" do
    it "yields configuration" do
      expect { |block|
        described_class.configure &block
      }.to yield_with_args(described_class.config)
    end
  end

  # TODO: remove default_fallbacks in v1.0
  %w[accessor_method query_method default_fallbacks new_fallbacks default_accessor_currencies].each do |delegated_method|
    describe ".#{delegated_method}" do
      it "delegates to config" do
        expect(described_class.config).to receive(delegated_method).and_return("foo")
        expect(described_class.send(delegated_method)).to eq("foo")
      end
    end
  end
end
