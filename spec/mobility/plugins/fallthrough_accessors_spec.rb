require "spec_helper"
require "mobility/plugins/fallthrough_accessors"

describe Mobility::Plugins::FallthroughAccessors do
  let(:attributes) do
    Mobility::Attributes.new(:amount, backend: :null).tap do |attributes|
      described_class.apply(attributes, option)
    end
  end
  let(:model_class) { Class.new.include attributes }

  context "option value is truthy" do
    let(:option) { true }
    it_behaves_like "currency accessor", :amount, :usd
    it_behaves_like "currency accessor", :amount, :eur
    it_behaves_like "currency accessor", :amount, :gbp
    it_behaves_like "currency accessor", :amount, :cad
  end

  context "option value is false" do
    let(:option) { false }
    it "does not include instance of FallthroughAccessors into attributes class" do
      instance = model_class.new
      expect { instance.amount_usd }.to raise_error(NoMethodError)
      expect { instance.amount_usd? }.to raise_error(NoMethodError)
      expect { instance.send(:amount_usd=, "value", {}) }.to raise_error(NoMethodError)
    end
  end
end
