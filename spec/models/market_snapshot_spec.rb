require "rails_helper"

RSpec.describe MarketSnapshot, type: :model do
  describe "validations" do
    it "is valid with symbol and timeframe" do
      snapshot = described_class.new(symbol: "EURUSD", timeframe: "H1")

      expect(snapshot).to be_valid
    end

    it "requires symbol" do
      snapshot = described_class.new(timeframe: "H1")

      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:symbol]).to include("can't be blank")
    end

    it "requires timeframe" do
      snapshot = described_class.new(symbol: "EURUSD")

      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:timeframe]).to include("can't be blank")
    end
  end

  describe "persistence" do
    it "stores indicator columns" do
      snapshot = described_class.create!(
        symbol: "EURUSD",
        timeframe: "H1",
        price: 1.08500,
        rsi: 55.25,
        ema50: 1.08400,
        ema200: 1.08200,
        support: 1.08000,
        resistance: 1.09000
      )

      snapshot.reload
      expect(snapshot.price).to eq(1.08500)
      expect(snapshot.rsi).to eq(55.25)
      expect(snapshot.ema50).to eq(1.08400)
      expect(snapshot.ema200).to eq(1.08200)
      expect(snapshot.support).to eq(1.08000)
      expect(snapshot.resistance).to eq(1.09000)
    end
  end
end
