require "spec_helper"
require "mobility/plugins/default"

describe Mobility::Plugins::Default do
  describe "when included into a class" do
    let(:default) { 'default foo' }
    let(:backend_double) { double("backend") }
    let(:backend) { backend_class.new("model", "amount") }
    let(:backend_class) do
      backend_double_ = backend_double
      backend_class = Mobility::Backends::Null.with_options(default: default)
      backend_class.class_eval do
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
      it "returns value if not nil" do
        expect(backend_double).to receive(:read).once.with(:eur, {}).and_return("foo")
        expect(backend.read(:eur)).to eq("foo")
      end

      it "returns value if value is false" do
        expect(backend_double).to receive(:read).once.with(:eur, {}).and_return(false)
        expect(backend.read(:eur)).to eq(false)
      end

      it "returns default if backend return value is nil" do
        expect(backend_double).to receive(:read).once.with(:eur, {}).and_return(nil)
        expect(backend.read(:eur)).to eq("default foo")
      end

      it "returns value of default override if passed as option to reader" do
        expect(backend_double).to receive(:read).once.with(:eur, {}).and_return(nil)
        expect(backend.read(:eur, default: "default bar")).to eq("default bar")
      end

      it "returns nil if passed default: nil as option to reader" do
        expect(backend_double).to receive(:read).once.with(:eur, {}).and_return(nil)
        expect(backend.read(:eur, default: nil)).to eq(nil)
      end

      it "returns false if passed default: false as option to reader" do
        expect(backend_double).to receive(:read).once.with(:eur, {}).and_return(nil)
        expect(backend.read(:eur, default: false)).to eq(false)
      end

      context "default is a Proc" do
        let(:default) { Proc.new { |attribute, currency, options| "#{attribute} in #{currency} with #{options[:this]}" } }

        it "calls default with model and attribute as args if default is a Proc" do
          expect(backend_double).to receive(:read).once.with(:eur, this: 'option').and_return(nil)
          expect(backend.read(:eur, this: 'option')).to eq("amount in eur with option")
        end

        it "calls default with model and attribute as args if default option is a Proc" do
          aggregate_failures do
            # with no arguments
            expect(backend_double).to receive(:read).once.with(:eur, this: 'option').and_return(nil)
            default_as_option = Proc.new { "default" }
            expect(backend.read(:eur, default: default_as_option, this: 'option')).to eq("default")

            # with one argument
            expect(backend_double).to receive(:read).once.with(:eur, this: 'option').and_return(nil)
            default_as_option = Proc.new { |attribute| "default #{attribute}" }
            expect(backend.read(:eur, default: default_as_option, this: 'option')).to eq("default amount")

            # with two arguments
            expect(backend_double).to receive(:read).once.with(:eur, this: 'option').and_return(nil)
            default_as_option = Proc.new { |attribute, currency| "default #{attribute} #{currency}" }
            expect(backend.read(:eur, default: default_as_option, this: 'option')).to eq("default amount eur")

            # with three arguments
            expect(backend_double).to receive(:read).once.with(:eur, this: 'option').and_return(nil)
            default_as_option = Proc.new { |attribute, currency, options| "default #{attribute} #{currency} #{options[:this]}" }
            expect(backend.read(:eur, default: default_as_option, this: 'option')).to eq("default amount eur option")

            # with any arguments
            expect(backend_double).to receive(:read).once.with(:eur, this: 'option').and_return(nil)
            default_as_option = Proc.new { |attribute, **| "default #{attribute}" }
            expect(backend.read(:eur, default: default_as_option, this: 'option')).to eq("default amount")
          end
        end
      end
    end
  end

  describe ".apply" do
    it "includes instance of default into backend class" do
      backend_class = double("backend class")
      attributes = instance_double(Mobility::Attributes, backend_class: backend_class)

      expect(backend_class).to receive(:include).with(described_class)
      described_class.apply(attributes, "default")
    end
  end
end
