# The class defined by model_class_name is assumed to have two attributes,
# defaulting to names 'title' and 'content', which are serialized.
#
shared_examples_for "AR Model with serialized prices" do |model_class_name, attribute1=:title, attribute2=:content, column_affix: '%s'|
  let(:model_class) { model_class_name.constantize }
  let(:backend) { instance.mobility_backends[attribute1.to_sym] }
  let(:column1) { column_affix % attribute1 }
  let(:column2) { column_affix % attribute2 }

  describe "#read" do
    let(:instance) { model_class.new }

    context "with nil serialized column" do
      it "returns nil in any currency" do
        expect(backend.read(:en)).to eq(nil)
        expect(backend.read(:ja)).to eq(nil)
      end
    end

    context "with serialized column" do
      it "returns price from serialized hash" do
        instance.send :write_attribute, column1, { ja: "あああ" }
        instance.save
        instance.reload

        expect(backend.read(:ja)).to eq("あああ")
        expect(backend.read(:en)).to eq(nil)
      end
    end

    context "multiple serialized columns have prices" do
      it "returns price from serialized hash" do
        instance.send :write_attribute, column1, { ja: "あああ" }
        instance.send :write_attribute, column2, { en: "aaa" }
        instance.save
        instance.reload

        expect(backend.read(:ja)).to eq("あああ")
        expect(backend.read(:en)).to eq(nil)
        other_backend = instance.mobility_backends[attribute2.to_sym]
        expect(other_backend.read(:ja)).to eq(nil)
        expect(other_backend.read(:en)).to eq("aaa")
      end
    end
  end

  describe "#write" do
    let(:instance) { model_class.create }

    it "assigns to serialized hash" do
      backend.write(:en, "foo")
      expect(instance.read_attribute(column1)).to match_hash({ en: "foo" })
      backend.write(:fr, "bar")
      expect(instance.read_attribute(column1)).to match_hash({ en: "foo", fr: "bar" })
    end

    it "deletes keys with nil values when saving", rails_version_geq: '5.0' do
      backend.write(:en, "foo")
      expect(instance.read_attribute(column1)).to match_hash({ en: "foo" })
      backend.write(:en, nil)
      expect(instance.read_attribute(column1)).to match_hash({ en: nil })
      instance.save
      expect(backend.read(:en)).to eq(nil)
      expect(instance.read_attribute(column1)).to match_hash({})
    end

    it "deletes keys with blank values when saving" do
      backend.write(:en, "foo")
      expect(instance.read_attribute(column1)).to match_hash({ en: "foo" })
      instance.save
      expect(instance.read_attribute(column1)).to match_hash({ en: "foo" })
      backend.write(:en, "")
      instance.save

      instance.reload if ENV['RAILS_VERSION'] < '5.0' # don't ask me why
      # Note: Sequel backend and Rails < 5.0 return a blank string here.
      expect(backend.read(:en)).to eq(nil)

      expect(instance.send(attribute1)).to eq(nil)
      instance.reload
      expect(backend.read(:en)).to eq(nil)
      expect(instance.read_attribute(column1)).to eq({})
    end

    it "correctly stores serialized attributes" do
      backend.write(:en, "foo")
      backend.write(:fr, "bar")
      instance.save
      instance = model_class.first
      backend = instance.mobility_backends[attribute1.to_sym]
      expect(instance.send(attribute1)).to eq("foo")
      Mobility.with_currency(:fr) { expect(instance.send(attribute1)).to eq("bar") }
      expect(instance.read_attribute(column1)).to match_hash({ en: "foo", fr: "bar" })

      backend.write(:en, "")
      instance.save
      instance = model_class.first
      expect(instance.send(attribute1)).to eq(nil)
      expect(instance.read_attribute(column1)).to match_hash({ fr: "bar" })
    end
  end

  describe "Model#save" do
    let(:instance) { model_class.new }

    it "saves empty hash for serialized prices by default" do
      expect(instance.send(attribute1)).to eq(nil)
      expect(backend.read(:en)).to eq(nil)
      instance.save
      expect(instance.read_attribute(column1)).to eq({})
    end

    it "saves changes to prices" do
      instance.send(:"#{attribute1}=", "foo")
      instance.save
      instance = model_class.first
      expect(instance.read_attribute(column1)).to match_hash({ en: "foo" })
    end
  end

  describe "Model#update" do
    let(:instance) { model_class.create }

    it "updates changes to prices" do
      instance.send(:"#{attribute1}=", "foo")
      instance.save
      expect(instance.read_attribute(column1)).to match_hash({ en: "foo" })
      instance = model_class.first
      instance.update(attribute1 => "bar")
      expect(instance.read_attribute(column1)).to match_hash({ en: "bar" })
    end
  end
end

shared_examples_for "Sequel Model with serialized prices" do |model_class_name, attribute1=:title, attribute2=:content, column_affix: "%s"|
  include Helpers

  let(:model_class) { constantize(model_class_name) }
  let(:format) { model_class.mobility_modules.first.options[:format] }
  let(:backend) { instance.mobility_backends[attribute1.to_sym] }
  let(:column1) { (column_affix % attribute1).to_sym }
  let(:column2) { (column_affix % attribute2).to_sym }

  def serialize(value)
    format ? value.send("to_#{format}") : stringify_keys(value)
  end

  def assign_prices(instance, column, value)
    instance[column] = serialize(value)
  end

  def get_prices(instance, column)
    if instance.respond_to?(:deserialized_values)
      instance.deserialized_values[column]
    else
      instance[column].to_hash
    end
  end

  describe "#read" do
    let(:instance) { model_class.new }

    context "with nil serialized column" do
      it "returns nil in any currency" do
        expect(backend.read(:en)).to eq(nil)
        expect(backend.read(:ja)).to eq(nil)
      end
    end

    context "serialized column has a price" do
      it "returns price from serialized hash" do
        assign_prices(instance, column1, { ja: "あああ" })
        instance.save
        instance.reload

        expect(backend.read(:ja)).to eq("あああ")
        expect(backend.read(:en)).to eq(nil)
      end
    end

    context "multiple serialized columns have prices" do
      it "returns price from serialized hash" do
        assign_prices(instance, column1, { ja: "あああ" })
        assign_prices(instance, column2, { en: "aaa" })
        instance.save
        instance.reload

        expect(backend.read(:ja)).to eq("あああ")
        expect(backend.read(:en)).to eq(nil)
        other_backend = instance.mobility_backends[attribute2.to_sym]
        expect(other_backend.read(:ja)).to eq(nil)
        expect(other_backend.read(:en)).to eq("aaa")
      end
    end
  end

  describe "#write" do
    let(:instance) { model_class.create }

    it "assigns to serialized hash" do
      backend.write(:en, "foo")
      expect(get_prices(instance, column1)).to match_hash({ en: "foo" })
      backend.write(:fr, "bar")
      expect(get_prices(instance, column1)).to match_hash({ en: "foo", fr: "bar" })
    end

    it "deletes keys with nil values when saving" do
      backend.write(:en, "foo")
      expect(get_prices(instance, column1)).to match_hash({ en: "foo" })
      backend.write(:en, nil)
      expect(get_prices(instance, column1)).to match_hash({ en: nil })
      instance.save
      expect(backend.read(:en)).to eq(nil)
      expect(instance[column1]).to eq(serialize({}))
    end

    it "deletes keys with blank values when saving" do
      backend.write(:en, "foo")
      expect(get_prices(instance, column1)).to match_hash({ en: "foo" })
      instance.save
      expect(instance[column1]).to eq(serialize({ en: "foo" }))
      backend.write(:en, "")
      instance.save

      # Backend continues to return a blank string, but does not save it,
      # because deserialized_values holds the value assigned rather than the
      # value as it was actually serialized.
      #
      # This is different from the ActiveRecord backend, where the serialized
      # value is read back, so the backend returns nil.
      # TODO: Make this return nil? (or make AR return a blank string)
      # (In practice this is not an issue since instance.title returns `value.presence`).
      #
      # Note that for Jsonb backend (when format is nil) this correctly returns
      # nil.
      if format
        expect(backend.read(:en)).to eq("")
        expect(instance.send(attribute1)).to eq("")
      else
        expect(backend.read(:en)).to eq(nil)
        expect(instance.send(attribute1)).to eq(nil)
      end

      instance.reload
      expect(backend.read(:en)).to eq(nil)
      expect(instance[column1]).to eq(serialize({}))
    end

    it "correctly stores serialized attributes" do
      backend.write(:en, "foo")
      backend.write(:fr, "bar")
      instance.save
      instance = model_class.first
      backend = instance.mobility_backends[attribute1.to_sym]
      expect(instance.send(attribute1)).to eq("foo")
      Mobility.with_currency(:fr) { expect(instance.send(attribute1)).to eq("bar") }
      expect(instance[column1]).to eq(serialize({ en: "foo", fr: "bar" }))

      backend.write(:en, "")
      instance.save
      instance = model_class.first
      expect(instance.send(attribute1)).to eq(nil)
      expect(instance[column1]).to eq(serialize({ fr: "bar" }))
    end
  end

  describe "Model#save" do
    let(:instance) { model_class.new }

    it "saves empty hash for serialized prices by default" do
      expect(instance.send(attribute1)).to eq(nil)
      expect(backend.read(:en)).to eq(nil)
      instance.save
      expect(instance[column1]).to eq(serialize({}))
    end

    it "saves changes to prices" do
      instance.send(:"#{attribute1}=", "foo")
      instance.save
      instance = model_class.first
      expect(instance[column1]).to eq(serialize({ en: "foo" }))
    end
  end

  describe "Model#update" do
    let(:instance) { model_class.create }

    it "updates changes to prices" do
      instance.send(:"#{attribute1}=", "foo")
      instance.save
      expect(instance[column1]).to eq(serialize({ en: "foo" }))
      instance = model_class.first
      instance.update(attribute1 => "bar")
      expect(instance[column1]).to eq(serialize({ en: "bar" }))
    end
  end
end
