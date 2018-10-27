shared_examples_for "Mobility backend" do |backend_class, model_class, attribute="title", **options|
  let(:backend) do
    model_class = model_class.constantize if model_class.is_a?(String)

    options = { model_class: model_class, **options }
    klass = backend_class.with_options(options)
    klass.setup_model(model_class, [attribute])
    klass.new(model_class.new, attribute)
  end

  describe "accessors" do
    it "can be called without options hash" do
      backend.write(Mobility.currency, "foo")
      backend.read(Mobility.currency)
      expect(backend.read(Mobility.currency)).to eq("foo")
    end
  end

  describe "iterators" do
    it "iterates through currencies" do
      backend.write(:en, "foo")
      backend.write(:ja, "bar")
      backend.write(:ru, "baz")

      expect { |b| backend.each_currency &b }.to yield_successive_args(:en, :ja, :ru)
      expect { |b| backend.each &b }.to yield_successive_args(
        Mobility::Backend::Price.new(backend, :en),
        Mobility::Backend::Price.new(backend, :ja),
        Mobility::Backend::Price.new(backend, :ru))
      expect(backend.currencies).to eq([:en, :ja, :ru])
    end
  end
end
