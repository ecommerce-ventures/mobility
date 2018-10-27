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
      let(:option) { [:cz, :de, :'pt-BR'] }

      it_behaves_like "currency accessor", :title, :cz
      it_behaves_like "currency accessor", :title, :de
      it_behaves_like "currency accessor", :title, :'pt-BR'

      it "raises NoMethodError if currency not in currencies" do
        instance = model_class.new
        aggregate_failures do
          expect { instance.title_en }.to raise_error(NoMethodError)
          expect { instance.title_en? }.to raise_error(NoMethodError)
          expect { instance.send(:title_en=, "value", {}) }.to raise_error(NoMethodError)
        end
      end

      it "warns currency option will be ignored if called with currency" do
        instance = model_class.new
        warning_message = /currency passed as option to currency accessor will be ignored/
        expect(instance).to receive(:title).with(currency: :cz).and_return("foo")
        expect { expect(instance.title_cz(currency: :en)).to eq("foo") }.to output(warning_message).to_stderr
        expect(instance).to receive(:title?).with(currency: :cz).and_return(true)
        expect { expect(instance.title_cz?(currency: :en)).to eq(true) }.to output(warning_message).to_stderr
        expect(instance).to receive(:title=).with("new foo", currency: :cz)
        expect { instance.send(:title_cz=, "new foo", currency: :en)}.to output(warning_message).to_stderr
      end
    end

    context "with option = true" do
      let(:option) { true }

      it "defines currency accessors for all currencies in I18n.available_currencies" do
        methods = model_class.instance_methods
        I18n.available_currencies.each do |currency|
          expect(methods).to include(:"title_#{Mobility.normalize_currency(currency)}")
          expect(methods).to include(:"title_#{Mobility.normalize_currency(currency)}?")
          expect(methods).to include(:"title_#{Mobility.normalize_currency(currency)}=")
        end
      end
    end

    describe "super: true" do
      let(:option) { [:en] }

      it "calls super of currency accessor method" do
        spy = double("model")
        klass = Class.new
        mod = Module.new do
          define_method :title_en do
            spy.title_en
          end
          define_method :title_en? do
            spy.title_en?
          end
          define_method :title_en= do |value|
            spy.title_en = value
          end
        end
        klass.include mod
        klass.include attributes

        instance = klass.new

        aggregate_failures do
          expect(spy).to receive(:title_en).and_return("model foo")
          expect(instance.title_en(super: true)).to eq("model foo")

          expect(spy).to receive(:title_en?).and_return(true)
          expect(instance.title_en?(super: true)).to eq(true)

          expect(spy).to receive(:title_en=).with("model foo")
          instance.send(:title_en=, "model foo", super: true)
        end
      end
    end
  end
end
