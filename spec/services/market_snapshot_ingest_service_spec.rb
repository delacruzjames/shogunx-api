require "rails_helper"

RSpec.describe MarketSnapshotIngestService do
  describe "#call" do
    it "creates D1, H4, and H1 snapshots from a flat payload" do
      params = {
        symbol: "XAUUSD",
        timeframe: "H4",
        price: 4448.87,
        rsi: 60.0,
        ema50: 4490.0,
        ema200: 4470.0,
        support: 4430.0,
        resistance: 4490.0
      }

      expect {
        described_class.new(params).call
      }.to change(MarketSnapshot, :count).by(3)

      expect(MarketSnapshot.pluck(:timeframe)).to match_array(%w[D1 H4 H1])
    end

    it "creates per-timeframe snapshots from a nested timeframes payload" do
      params = {
        symbol: "XAUUSD",
        timeframe: "H4",
        timeframes: {
          "D1" => { price: 4500, rsi: 55, ema50: 4510, ema200: 4490, support: 4480, resistance: 4520 },
          "H4" => { price: 4448, rsi: 60, ema50: 4490, ema200: 4470, support: 4430, resistance: 4490 },
          "H1" => { price: 4440, rsi: 45, ema50: 4450, ema200: 4460, support: 4435, resistance: 4455 }
        }
      }

      primary = described_class.new(params).call

      expect(primary.timeframe).to eq("H4")
      expect(primary.price).to eq(4448)
      expect(MarketSnapshot.find_by!(timeframe: "D1").price).to eq(4500)
      expect(MarketSnapshot.find_by!(timeframe: "H1").price).to eq(4440)
    end
  end
end
