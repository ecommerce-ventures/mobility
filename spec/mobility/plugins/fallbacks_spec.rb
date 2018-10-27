require "spec_helper"
require "mobility/plugins/fallbacks"

describe Mobility::Plugins::Fallbacks do
  describe "when included into a class" do
    let(:backend_class) do
      backend_class = stub_const 'MyBackend', Class.new
      backend_class.include(Mobility::Backend)
      backend_subclass = backend_class.with_options(fallbacks: fallbacks)
      backend_subclass.class_eval do
        def read(currency, **options)
          Mobility.enforce_available_currencies!(currency)
          return "bar" if options[:bar]
          {
            "title" => {
              :'de-DE' => "foo",
              :ja => "フー",
              :'pt' => ""
            }
          }[attribute][currency]
        end
      end
      Class.new(backend_subclass).include(described_class.new(fallbacks))
    end
    let(:object) { (stub_const 'MobilityModel', Class.new).include(Mobility).new }
    subject { backend_class.new(object, "title") }

    context "fallbacks is a hash" do
      let(:fallbacks) { { :'en-US' => 'de-DE', :pt => 'de-DE' } }

      it "returns value when value is not nil" do
        expect(subject.read(:ja)).to eq("フー")
      end

      it "falls through to fallback currency when value is nil" do
        expect(subject.read(:"en-US")).to eq("foo")
      end

      it "falls through to fallback currency when value is blank" do
        expect(subject.read(:pt)).to eq("foo")
      end

      it "returns nil when no fallback is found" do
        expect(subject.read(:fr)).to eq(nil)
      end

      it "returns nil when fallback: false option is passed" do
        expect(subject.read(:"en-US", fallback: false)).to eq(nil)
      end

      it "falls through to fallback currency when fallback: true option is passed" do
        expect(subject.read(:"en-US", fallback: true)).to eq("foo")
      end

      it "uses currency passed in as value of fallback option when present" do
        expect(subject.read(:"en-US", fallback: :ja)).to eq("フー")
      end

      it "uses array of currencies passed in as value of fallback options when present" do
        expect(subject.read(:"en-US", fallback: [:pl, :'de-DE'])).to eq("foo")
      end

      it "passes options to getter in fallback currency" do
        expect(subject.read(:'en-US', bar: true)).to eq("bar")
      end

      it "does not modify options passed in" do
        options = { fallback: false }
        subject.read(:"en-US", options)
        expect(options).to eq({ fallback: false })
      end
    end

    context "fallbacks is true" do
      let(:fallbacks) { true }

      it "uses default fallbacks" do
        original_default_currency = Mobility.default_currency
        Mobility.default_currency = :ja
        expect(subject.read(:"en-US")).to eq(value)
        Mobility.default_currency = original_default_currency
      end
    end

    context "fallbacks is falsey" do
      let(:fallbacks) { nil }

      it "does not use fallbacks when fallback option is false or nil" do
        original_default_currency = Mobility.default_currency
        Mobility.default_currency = :ja
        expect(subject.read(:"en-US")).to eq(nil)
        Mobility.default_currency = original_default_currency
        expect(subject.read(:"en-US", fallback: false)).to eq(nil)
        Mobility.default_currency = original_default_currency
      end

      it "uses currency passed in as value of fallback option when present" do
        expect(subject.read(:"en-US", fallback: :ja)).to eq("フー")
      end

      it "uses array of currencies passed in as value of fallback options when present" do
        expect(subject.read(:"en-US", fallback: [:pl, :'de-DE'])).to eq("foo")
      end

      it "does not use fallbacks when fallback: true option is passed" do
        expect(subject.read(:"en-US", fallback: true)).to eq(nil)
      end
    end
  end

  describe ".apply" do
    let(:attributes) { instance_double(Mobility::Attributes, backend_class: backend_class) }
    let(:backend_class) { double("backend class") }
    let(:fallbacks) { instance_double(described_class) }

    context "option value is not false" do
      it "includes instance of fallbacks into backend class" do
        expect(described_class).to receive(:new).with("option").and_return(fallbacks)
        expect(backend_class).to receive(:include).with(fallbacks)
        described_class.apply(attributes, "option")
      end
    end

    context "optoin value is false" do
      it "does nothing" do
        expect(attributes).not_to receive(:backend_class)
        described_class.apply(attributes, false)
      end
    end
  end
end
