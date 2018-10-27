shared_examples_for "currency accessor" do |attribute, currency|
  let(:options) { { these: "options" } }

  it "handles getters and setters for currency=#{currency}" do
    instance = model_class.new
    normalized_currency = currency.to_s.gsub('-', '_').downcase.to_sym

    aggregate_failures "getter" do
      expect(instance).to receive(attribute).with(**options, currency: currency).and_return("foo")
      expect(instance.send(:"#{attribute}_#{normalized_currency}", options)).to eq("foo")
    end

    aggregate_failures "presence" do
      expect(instance).to receive(:"#{attribute}?").with(**options, currency: currency).and_return(true)
      expect(instance.send(:"#{attribute}_#{normalized_currency}?", options)).to eq(true)
    end

    aggregate_failures "setter" do
      expect(instance).to receive(:"#{attribute}=").with("value", **options, currency: currency).and_return("value")
      expect(instance.send(:"#{attribute}_#{normalized_currency}=", "value", options)).to eq("value")
    end
  end
end
