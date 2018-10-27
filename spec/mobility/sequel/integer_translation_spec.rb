require "spec_helper"

describe "Mobility::Sequel::IntegerPrice", orm: :sequel do
  let(:described_class) { Mobility::Sequel::IntegerPrice }

  describe "#priceable" do
    it "gets priceable model" do
      post = Post.create
      price = described_class.create(
        priceable_id: post.id,
        priceable_type: "Post",
        currency: "en",
        key: "content",
        value: "some content"
      )
      expect(price.priceable).to eq(post)
      expect(price.priceable).to eq(post)
    end
  end

  describe "#priceable=" do
    it "sets priceable model" do
      post = Post.create
      price = described_class.new(
        currency: "en",
        key: "content",
        value: "some content"
      )
      price.priceable = post
      price.save
      price.reload
      expect(price.priceable).to eq(post)
    end
  end
end
