shared_examples_for "Mobility backend" do |backend_class, model_class, attribute="amount", **options|
  let(:backend) do
    model_class = model_class.constantize if model_class.is_a?(String)

    options = { model_class: model_class, **options }
    klass = backend_class.with_options(options)
    klass.setup_model(model_class, [attribute])
    klass.new(model_class.new, attribute)
  end

  describe "accessors" do
    it "can be called without options hash" do
      backend.write(Mobility.currency, 100)
      backend.read(Mobility.currency)
      expect(backend.read(Mobility.currency)).to eq(100)
    end
  end

  describe "iterators" do
    it "iterates through currencies" do
      backend.write(:usd, 100)
      backend.write(:jpy, 200)
      backend.write(:gbp, 300)

      expect { |b| backend.each_currency &b }.to yield_successive_args(:usd, :jpy, :gbp)
      expect { |b| backend.each &b }.to yield_successive_args(
        Mobility::Backend::Price.new(backend, :usd),
        Mobility::Backend::Price.new(backend, :jpy),
        Mobility::Backend::Price.new(backend, :gbp))
      expect(backend.currencies).to eq([:usd, :jpy, :gbp])
    end
  end
end
