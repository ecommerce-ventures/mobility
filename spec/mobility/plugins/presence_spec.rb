require "spec_helper"
require "mobility/plugins/presence"

describe Mobility::Plugins::Presence do
  describe "when included into a class" do
    let(:backend_double) { double("backend") }
    let(:backend) { backend_class.new("model", "attribute") }
    let(:backend_class) do
      backend_double_  = backend_double
      backend_class = Class.new(Mobility::Backends::Null) do
        define_method :read do |*args|
          backend_double_.read(*args)
        end

        define_method :write do |*args|
          backend_double_.write(*args)
        end
      end
      Class.new(backend_class).include(described_class)
    end

    describe "#read" do
      it "passes through present values unchanged" do
        expect(backend_double).to receive(:read).once.with(:eur, {}).and_return("foo")
        expect(backend.read(:eur)).to eq("foo")
      end

      it "converts blank strings to nil" do
        expect(backend_double).to receive(:read).once.with(:eur, {}).and_return("")
        expect(backend.read(:eur)).to eq(nil)
      end

      it "passes through nil values unchanged" do
        expect(backend_double).to receive(:read).once.with(:eur, {}).and_return(nil)
        expect(backend.read(:eur)).to eq(nil)
      end

      it "passes through false values unchanged" do
        expect(backend_double).to receive(:read).once.with(:eur, {}).and_return(false)
        expect(backend.read(:eur)).to eq(false)
      end

      it "does not convert blank string to nil if presence: false passed as option" do
        expect(backend_double).to receive(:read).once.with(:eur, {}).and_return("")
        expect(backend.read(:eur, presence: false)).to eq("")
      end

      it "does not modify options passed in" do
        options = { presence: false }
        expect(backend_double).to receive(:read).once.with(:eur, {}).and_return("")
        backend.read(:eur, options)
        expect(options).to eq({ presence: false })
      end
    end

    describe "#write" do
      it "passes through present values unchanged" do
        expect(backend_double).to receive(:write).once.with(:eur, "foo", {}).and_return("foo")
        expect(backend.write(:eur, "foo")).to eq("foo")
      end

      it "converts blank strings to nil" do
        expect(backend_double).to receive(:write).once.with(:eur, nil, {}).and_return(nil)
        expect(backend.write(:eur, "")).to eq(nil)
      end

      it "passes through nil values unchanged" do
        expect(backend_double).to receive(:write).once.with(:eur, nil, {}).and_return(nil)
        expect(backend.write(:eur, nil)).to eq(nil)
      end

      it "passes through false values unchanged" do
        expect(backend_double).to receive(:write).once.with(:eur, false, {}).and_return(false)
        expect(backend.write(:eur, false)).to eq(false)
      end

      it "does not convert blank string to nil if presence: false passed as option" do
        expect(backend_double).to receive(:write).once.with(:eur, "", {}).and_return("")
        expect(backend.write(:eur, "", presence: false)).to eq("")
      end

      it "does not modify options passed in" do
        options = { presence: false }
        expect(backend_double).to receive(:write).once.with(:eur, "foo", {})
        backend.write(:eur, "foo", options)
        expect(options).to eq({ presence: false })
      end
    end
  end

  # this is identical to apply specs for Cache, and can probably be refactored
  describe ".apply" do
    context "option value is truthy" do
      it "includes Presence into backend class" do
        backend_class = double("backend class")
        attributes = instance_double(Mobility::Attributes, backend_class: backend_class)
        expect(backend_class).to receive(:include).twice.with(described_class)
        described_class.apply(attributes, true)
        described_class.apply(attributes, [])
      end
    end

    context "option value is falsey" do
      it "does not include Presence into backend class" do
        attributes = instance_double(Mobility::Attributes)
        expect(attributes).not_to receive(:backend_class)
        described_class.apply(attributes, false)
        described_class.apply(attributes, nil)
      end
    end
  end
end
