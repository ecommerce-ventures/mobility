require "spec_helper"

describe "Mobility::Backends::ActiveRecord::Column", orm: :active_record do
  require "mobility/backends/active_record/column"
  extend Helpers::ActiveRecord

  context "with no plugins applied" do
    model_class = Class.new(ActiveRecord::Base) do
      extend Mobility
      self.table_name = 'comments'
    end
    include_backend_examples described_class, model_class, "amount"
  end

  context "with standard plugins applied" do
    let(:attributes) { %w[amount tax] }
    let(:options) { {} }
    let(:backend) do
      described_class.with_options(options).new(comment, attributes.first)
    end
    let(:comment) do
      Comment.create(amount_usd: 100,
                     amount_jpy: 200,
                     amount_gbp: 300)
    end

    before do
      stub_const 'Comment', Class.new(ActiveRecord::Base)
      Comment.extend Mobility
      Comment.translates *attributes, backend: :column, cache: false
    end

    subject { comment }

    include_cache_key_examples "Comment", :amount

    describe "#read" do
      it "returns attribute in currency from appropriate column" do
        aggregate_failures do
          expect(backend.read(:usd)).to eq(100)
          expect(backend.read(:jpy)).to eq(200)
        end
      end

      it "handles dashed currencies" do
        expect(backend.read(:gbp)).to eq(300)
      end
    end

    describe "#write" do
      it "assigns to appropriate columnn" do
        backend.write(:usd, 100)
        backend.write(:jpy, 200)

        aggregate_failures do
          expect(comment.amount_usd).to eq(100)
          expect(comment.amount_jpy).to eq(200)
        end
      end

      it "handles dashed currencies" do
        backend.write(:gbp, 300)
        expect(comment.amount_gbp).to eq 300
      end
    end

    describe "Model accessors" do
      include_accessor_examples 'Comment', :amount, :tax
      include_dup_examples 'Comment', :amount
    end

    describe "with currency accessors" do
      it "still works as usual" do
        Comment.translates *attributes, backend: :column, cache: false, currency_accessors: true
        backend.write(:usd, 100)
        expect(comment.amount_usd).to eq(100)
      end
    end

    describe "with dirty" do
      it "still works as usual" do
        Comment.translates *attributes, backend: :column, cache: false, dirty: true
        backend.write(:usd, 100)
        expect(comment.amount_usd).to eq(100)
      end

      it "tracks changed attributes" do
        Comment.translates *attributes, backend: :column, cache: false, dirty: true
        comment = Comment.new

        aggregate_failures do
          expect(comment.amount).to eq(nil)
          expect(comment.changed?).to eq(false)
          expect(comment.changed).to eq([])
          expect(comment.changes).to eq({})

          comment.amount = 100
          expect(comment.amount).to eq(100)
          expect(comment.changed?).to eq(true)
          expect(comment.changed).to eq(["amount_usd"])
          expect(comment.changes).to eq({ "amount_usd" => [nil, 100] })
        end
      end

      it "returns nil for currencies with no column defined" do
        Comment.translates *attributes, backend: :column, cache: false, dirty: true
        comment = Comment.new

        expect(comment.amount(currency: :eur)).to eq(nil)
      end
    end

    describe "mobility scope (.i18n)" do
      include_querying_examples 'Comment', :amount, :tax
      include_validation_examples 'Comment', :amount, :tax
    end
  end
end if Mobility::Loaded::ActiveRecord
