require "spec_helper"
require "mobility/plugins/currency_accessors"

describe Mobility::Plugins::CurrencyAccessors do
  let(:attributes) do
    Mobility::Attributes.new(:title, backend: :null).tap do |attributes|
      described_class.apply(attributes, option)
    end
  end
  let(:model_class) { Class.new.include attributes }

  describe "when included into a class" do
    context "with currencies set" do
      let(:option) { [:usd, :eur, :gbp] }

      it_behaves_like "currency accessor", :title, :usd
      it_behaves_like "currency accessor", :title, :eur
      it_behaves_like "currency accessor", :title, :gbp

      it "raises NoMethodError if currency not in currencies" do
        instance = model_class.new
        aggregate_failures do
          expect { instance.title_cad }.to raise_error(NoMethodError)
          expect { instance.title_cad? }.to raise_error(NoMethodError)
          expect { instance.send(:title_cad=, "value", {}) }.to raise_error(NoMethodError)
        end
      end

      it "warns currency option will be ignored if called with currency" do
        instance = model_class.new
        warning_message = /currency passed as option to currency accessor will be ignored/
        expect(instance).to receive(:title).with(currency: :usd).and_return(100)
        expect { expect(instance.title_usd(currency: :usd)).to eq(100) }.to output(warning_message).to_stderr
        expect(instance).to receive(:title?).with(currency: :usd).and_return(true)
        expect { expect(instance.title_usd?(currency: :usd)).to eq(true) }.to output(warning_message).to_stderr
        expect(instance).to receive(:title=).with(110, currency: :usd)
        expect { instance.send(:title_usd=, 110, currency: :usd)}.to output(warning_message).to_stderr
      end
    end

    context "with option = true" do
      let(:option) { true }

      it "defines currency accessors for all currencies in Mobility.available_currencies" do
        methods = model_class.instance_methods
        Mobility.available_currencies.each do |currency|
          expect(methods).to include(:"title_#{Mobility.normalize_currency(currency)}")
          expect(methods).to include(:"title_#{Mobility.normalize_currency(currency)}?")
          expect(methods).to include(:"title_#{Mobility.normalize_currency(currency)}=")
        end
      end
    end

    describe "super: true" do
      let(:option) { [:usd] }

      it "calls super of currency accessor method" do
        spy = double("model")
        klass = Class.new
        mod = Module.new do
          define_method :title_usd do
            spy.title_usd
          end
          define_method :title_usd? do
            spy.title_usd?
          end
          define_method :title_usd= do |value|
            spy.title_usd = value
          end
        end
        klass.include mod
        klass.include attributes

        instance = klass.new

        aggregate_failures do
          expect(spy).to receive(:title_usd).and_return("model foo")
          expect(instance.title_usd(super: true)).to eq("model foo")

          expect(spy).to receive(:title_usd?).and_return(true)
          expect(instance.title_usd?(super: true)).to eq(true)

          expect(spy).to receive(:title_usd=).with("model foo")
          instance.send(:title_usd=, "model foo", super: true)
        end
      end
    end
  end
end
