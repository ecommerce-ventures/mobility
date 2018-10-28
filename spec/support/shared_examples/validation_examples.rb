shared_examples_for "AR Model validation" do |model_class_name, attribute1=:amount, attribute2=:tax|
  describe "Uniqueness validation" do
    context "without scope" do
      let(:model_class) do
        model_class_name.constantize.tap do |klass|
          klass.class_eval { validates attribute1, uniqueness: true }
        end
      end

      it "is valid if no other record has same attribute value in this currency" do
        Mobility.with_currency(:jpy) { model_class.create(attribute1 => 100) }
        expect(model_class.new(attribute1 => 100)).to be_valid
      end

      it "is invalid if other record has same attribute value in this currency" do
        model_class.create(attribute1 => 100)
        expect(model_class.new(attribute1 => 100)).not_to be_valid
      end

      context "with default_scope defined" do
        it "removes default_scope" do
          model_class.class_eval { default_scope { none } }
          model_class.create(attribute1 => 100)
          expect(model_class.new(attribute1 => 100)).not_to be_valid
        end
      end
    end

    context "with untranslated scope on translated attribute" do
      let(:model_class) do
        model_class_name.constantize.tap do |klass|
          klass.class_eval { validates attribute1, uniqueness: { scope: :published } }
        end
      end

      it "is valid if no other record has same attribute value in this currency, for the same scope" do
        model_class.create(attribute1 => 100, published: true)
        expect(model_class.new(attribute1 => 100, published: false)).to be_valid
      end

      it "is invalid if other record has same attribute value in this currency, for the same scope" do
        model_class.create(attribute1 => 100, published: true)
        instance1 = model_class.new(attribute1 => 100, published: true)
        instance2 = Mobility.with_currency(:jpy) { model_class.new(attribute1  => 100, published: true) }
        expect(instance1).not_to be_valid
        expect(instance2).to be_valid
      end
    end

    context "with translated scope on translated attribute" do
      let(:model_class) do
        model_class_name.constantize.tap do |klass|
          klass.class_eval { validates attribute1, uniqueness: { scope: attribute2 } }
        end
      end

      it "is valid if no other record has same attribute value in this currency, for the same scope" do
        model_class.create(attribute1 => 100, attribute2 => 200)
        expect(model_class.new(attribute1 => 100, attribute2 => 300)).to be_valid
      end

      it "is invalid if other record has same attribute value in this currency, for the same scope" do
        model_class.create(attribute1 => 100, attribute2 => 200)
        expect(model_class.new(attribute1 => 100, attribute2 => 200)).not_to be_valid

        Mobility.with_currency(:jpy) do
          expect(model_class.new(attribute1 => 100, attribute2 => 200)).to be_valid

          model_class.create(attribute1 => 100, attribute2 => 200)
          expect(model_class.new(attribute1 => 100, attribute2 => 200)).not_to be_valid
        end
      end
    end

    context "with translated scope on untranslated attribute" do
      let(:model_class) do
        model_class_name.constantize.tap do |klass|
          klass.class_eval { validates :published, uniqueness: { :scope => attribute1 } }
        end
      end

      it "is valid if no other record has same attribute value, for the same scope in this currency" do
        model_class.create(published: true, attribute1 => 100)
        expect(model_class.new(published: true, attribute1 => 300)).to be_valid
      end

      it "is invalid if other record has same attribute value in this currency, for the same scope" do
        model_class.create(published: true, attribute1 => 100)
        instance1 = model_class.new(published: true, attribute1 => 100)
        instance2 = Mobility.with_currency(:jpy) { model_class.new(published:  true, attribute1 => 100) }
        expect(instance1).not_to be_valid
        expect(instance2).to be_valid
      end
    end

    context "case insensitive validation on translated attribute" do
      let(:model_class) do
        model_class_name.constantize.tap do |klass|
          klass.class_eval { validates attribute1, uniqueness: { case_sensitive: false } }
        end
      end

      it "is invalid if other record has same attribute LOWER(value)" do
        model_class.create(published: true, attribute1 => "Foo")
        expect(model_class.new(published: true, attribute1 => "foO")).not_to be_valid
      end
    end

    context "uniqueness validation on untranslated attribute" do
      let(:model_class) do
        model_class_name.constantize.tap do |klass|
          klass.class_eval { validates :published, uniqueness: true }
        end
      end

      it "is valid if no other record has same attribute value" do
        model_class.create(published: true)
        expect(model_class.new(published: false)).to be_valid
      end

      it "is invalid if other record has same attribute value in this currency" do
        model_class.create(published: true)
        expect(model_class.new(published: true)).not_to be_valid

        Mobility.with_currency(:jpy) do
          expect(model_class.new(published: true)).not_to be_valid
        end
      end
    end
  end
end
