require "spec_helper"

describe Mobility::Configuration do
  subject { Mobility::Configuration.new }

  it "initializes new fallbacks instance to I18n::Currency::Fallbacks.new" do
    expect(subject.new_fallbacks).to be_a(I18n::Currency::Fallbacks)
    expect(subject.default_fallbacks).to be_a(I18n::Currency::Fallbacks) # TODO: remove in v1.0
  end

  it "initializes default accessor_currencies to I18n.available_currencies" do
    expect(subject.default_accessor_currencies).to eq(I18n.available_currencies)
  end

  it "sets default_backend to nil" do
    expect(subject.default_backend).to eq(nil)
  end

  describe "#default_accessor_currencies=" do
    it "returns array of currencies if assigned array" do
      subject.default_accessor_currencies = [:en, :ja]
      expect(subject.default_accessor_currencies).to eq([:en, :ja])
    end

    it "returned proc evaluated when called if assigned a proc" do
      @accessor_currencies = [:en, :fr]
      subject.default_accessor_currencies = lambda { @accessor_currencies }
      expect(subject.default_accessor_currencies).to eq([:en, :fr])
      @accessor_currencies = [:en, :de]
      expect(subject.default_accessor_currencies).to eq([:en, :de])
    end
  end

  describe "#default_options" do
    it "raises exception when reserved option keys are set" do
      aggregate_failures do
        %i[backend model_class].each do |reserved_key|
          expect {
            subject.default_options[reserved_key] = "value"
          }.to raise_error(Mobility::Configuration::ReservedOptionKey)
        end
      end
    end
  end
end
