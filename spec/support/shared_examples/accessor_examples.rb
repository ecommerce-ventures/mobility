# Basic test of translated attribute accessors which can be applied to any
# backend, and (since there is no ORM-specific code here) to any ORM.
shared_examples_for "model with translated attribute accessors" do |model_class_name, attribute1=:amount, attribute2=:tax, **options|
  let(:model_class) { constantize(model_class_name) }
  let(:instance) { model_class.new }

  it "gets and sets prices in one currency" do
    aggregate_failures "before saving" do
      instance.public_send(:"#{attribute1}=", 100)
      expect(instance.public_send(attribute1)).to eq(100)

      instance.public_send(:"#{attribute2}=", 200)
      expect(instance.public_send(attribute2)).to eq(200)

      instance.save
    end

    aggregate_failures "after reload" do
      instance = model_class.first

      expect(instance.public_send(attribute1)).to eq(100)
      expect(instance.public_send(attribute2)).to eq(200)
    end
  end

  it "gets and sets prices in multiple currencies" do
    aggregate_failures "before saving" do
      instance.public_send(:"#{attribute1}=", 100)
      instance.public_send(:"#{attribute2}=", 200)
      Mobility.with_currency(:jpy) do
        instance.public_send(:"#{attribute1}=", 300)
      end

      expect(instance.public_send(attribute1)).to eq(100)
      expect(instance.public_send(attribute2)).to eq(200)
      Mobility.with_currency(:jpy) do
        expect(instance.public_send(attribute1)).to eq(300)
        expect(instance.public_send(attribute2)).to eq(nil)
        expect(instance.public_send(attribute1, { currency: :usd })).to eq(100)
        expect(instance.public_send(attribute2, { currency: :usd })).to eq(200)
      end
      expect(instance.public_send(attribute1, { currency: :jpy })).to eq(300)
    end

    instance.save
    instance = model_class.first

    aggregate_failures "after reload" do
      expect(instance.public_send(attribute1)).to eq(100)
      expect(instance.public_send(attribute2)).to eq(200)

      Mobility.with_currency(:jpy) do
        expect(instance.public_send(attribute1)).to eq(300)
        expect(instance.public_send(attribute2)).to eq(nil)
      end
    end
  end

  it "sets prices in multiple currencies when creating and saving model" do
    aggregate_failures do
      instance = model_class.create(attribute1 => 100, attribute2 => 200)

      expect(instance.send(attribute1)).to eq(100)
      expect(instance.send(attribute2)).to eq(200)

      Mobility.with_currency(:jpy) { instance.send("#{attribute1}=", 300) }
      instance.save

      instance = model_class.first

      expect(instance.send(attribute1)).to eq(100)
      Mobility.with_currency(:jpy) { expect(instance.send(attribute1)).to eq(300) }
      Mobility.with_currency(:jpy) { expect(instance.send(attribute2)).to eq(nil) }
    end
  end

  it "sets prices in multiple currencies when updating model" do
    instance = model_class.create

    aggregate_failures "setting attributes with update" do
      instance.update(attribute1 => 100)
      expect(instance.send(attribute1)).to eq(100)
      Mobility.with_currency(:jpy) do
        instance.update(attribute1 => 300)
        expect(instance.send(attribute1)).to eq(300)
      end
    end

    instance = model_class.first

    aggregate_failures "reading attributes from db after update" do
      expect(instance.send(attribute1)).to eq(100)
      Mobility.with_currency(:jpy) { expect(instance.send(attribute1)).to eq(300) }
    end
  end
end

shared_examples_for "Sequel model with translated attribute accessors" do |model_class_name, attribute1=:title, attribute2=:content, **options|
  let(:model_class) { constantize(model_class_name) }

  it "marks model as modified if price(s) change" do
    instance = model_class.create(attribute1 => 100)

    aggregate_failures "before saving" do
      expect(instance.modified?).to eq(false)

      instance.send("#{attribute1}=", 200)
      expect(instance.modified?).to eq(true)
    end

    instance.save

    aggregate_failures "after saving" do
      expect(instance.modified?).to eq(false)
      instance.send("#{attribute1}=", 200)
      instance.modified?
      expect(instance.modified?).to eq(false)
      instance.send("#{attribute1}=", 100)
      expect(instance.modified?).to eq(true)
    end
  end
end
