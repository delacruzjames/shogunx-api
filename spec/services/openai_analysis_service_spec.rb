require "rails_helper"

RSpec.describe OpenaiAnalysisService do
  def create_snapshot(ema50:, ema200:, rsi:, price: 4448.87)
    MarketSnapshot.create!(
      symbol: "XAUUSD",
      timeframe: "H4",
      price: price,
      rsi: rsi,
      ema50: ema50,
      ema200: ema200,
      support: 4430,
      resistance: 4490
    )
  end

  describe "#call" do
    it "returns WAIT when there is no market data" do
      result = described_class.new.call

      expect(result).to eq(
        action: "WAIT",
        confidence: 0,
        timeframe: "H4",
        reason: "Insufficient market data for analysis"
      )
    end

    it "returns BUY when ema50 > ema200 and RSI is between 50 and 70" do
      create_snapshot(ema50: 4490, ema200: 4470, rsi: 60)

      result = described_class.new.call

      expect(result[:action]).to eq("BUY")
      expect(result[:confidence]).to eq(50)
      expect(result[:timeframe]).to eq("H4")
      expect(result[:reason]).to include("EMA50 above EMA200")
      expect(result[:reason]).to include("50–70")
    end

    it "returns higher BUY confidence when RSI is near the top of the buy band" do
      create_snapshot(ema50: 4490, ema200: 4470, rsi: 70)

      result = described_class.new.call

      expect(result[:action]).to eq("BUY")
      expect(result[:confidence]).to eq(100)
    end

    it "returns SELL when ema50 < ema200 and RSI is between 30 and 50" do
      create_snapshot(ema50: 4470, ema200: 4490, rsi: 40)

      result = described_class.new.call

      expect(result[:action]).to eq("SELL")
      expect(result[:confidence]).to eq(50)
      expect(result[:timeframe]).to eq("H4")
      expect(result[:reason]).to include("EMA50 below EMA200")
      expect(result[:reason]).to include("30–50")
    end

    it "returns higher SELL confidence when RSI is near the top of the sell band" do
      create_snapshot(ema50: 4470, ema200: 4490, rsi: 50)

      result = described_class.new.call

      expect(result[:action]).to eq("SELL")
      expect(result[:confidence]).to eq(100)
    end

    it "returns WAIT when trend is bullish but RSI is outside the buy band" do
      create_snapshot(ema50: 4490, ema200: 4470, rsi: 45)

      result = described_class.new.call

      expect(result).to eq(
        action: "WAIT",
        confidence: 0,
        timeframe: "H4",
        reason: "Bullish EMA trend but RSI 45.00 outside 50–70 buy range"
      )
    end

    it "returns WAIT when trend is bearish but RSI is outside the sell band" do
      create_snapshot(ema50: 4470, ema200: 4490, rsi: 55)

      result = described_class.new.call

      expect(result).to eq(
        action: "WAIT",
        confidence: 0,
        timeframe: "H4",
        reason: "Bearish EMA trend but RSI 55.00 outside 30–50 sell range"
      )
    end

    it "returns WAIT when EMA50 equals EMA200" do
      create_snapshot(ema50: 4480, ema200: 4480, rsi: 60)

      result = described_class.new.call

      expect(result[:action]).to eq("WAIT")
      expect(result[:confidence]).to eq(0)
      expect(result[:reason]).to include("EMA50 and EMA200 aligned")
    end
  end

  describe "#market_summary" do
    it "uses MarketSummaryService for the latest XAUUSD snapshot" do
      create_snapshot(ema50: 4490, ema200: 4470, rsi: 60, price: 4500)

      summary = described_class.new.market_summary

      expect(summary[:symbol]).to eq("XAUUSD")
      expect(summary[:current_price]).to eq(4500)
      expect(summary[:current_rsi]).to eq(60)
      expect(summary[:trend]).to eq("bullish")
      expect(summary[:snapshot_count]).to eq(1)
    end
  end
end
