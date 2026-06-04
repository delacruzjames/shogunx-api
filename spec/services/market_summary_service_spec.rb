require "rails_helper"

RSpec.describe MarketSummaryService do
  describe "#call" do
    it "returns unavailable timeframe summaries when no snapshots exist" do
      summary = described_class.new.call

      expect(summary[:symbol]).to eq("XAUUSD")
      expect(summary[:current_price]).to be_nil
      expect(summary[:timeframes]["D1"][:available]).to be(false)
      expect(summary[:timeframes]["H4"][:available]).to be(false)
      expect(summary[:timeframes]["H1"][:available]).to be(false)
      expect(summary[:snapshot_count]).to eq(0)
    end

    it "summarizes each analysis timeframe independently" do
      create_multi_timeframe_snapshots(
        price: 4448.87,
        rsi: 36.97,
        ema50: 4483.80,
        ema200: 4506.55,
        support: 4438.85,
        resistance: 4496.63
      )
      MarketSnapshot.where(timeframe: "D1").order(created_at: :desc).first.update!(
        price: 4500,
        rsi: 55,
        ema50: 4510,
        ema200: 4490
      )

      summary = described_class.new.call

      expect(summary[:symbol]).to eq("XAUUSD")
      expect(summary[:current_price]).to eq(4448.87)
      expect(summary[:timeframes]["H4"][:trend]).to eq("bearish")
      expect(summary[:timeframes]["D1"][:current_price]).to eq(4500)
      expect(summary[:timeframes]["D1"][:trend]).to eq("bullish")
      expect(summary[:snapshot_count]).to eq(3)
    end

    it "loads only the latest 10 snapshots per timeframe" do
      12.times do |i|
        create_multi_timeframe_snapshots(
          price: 4400 + i,
          rsi: 10 * i,
          ema50: 4480,
          ema200: 4500,
          support: 4430,
          resistance: 4490,
          created_at: i.hours.ago
        )
      end

      summary = described_class.new.call

      expect(summary[:timeframes]["H4"][:snapshot_count]).to eq(10)
      expect(summary[:timeframes]["H4"][:current_price]).to eq(4400)
      expect(summary[:timeframes]["H4"][:average_rsi]).to eq(45.0)
    end

    it "allows a custom symbol" do
      MarketSnapshot::ANALYSIS_TIMEFRAMES.each do |timeframe|
        MarketSnapshot.create!(
          symbol: "EURUSD",
          timeframe: timeframe,
          price: 1.085,
          rsi: 55,
          ema50: 1.090,
          ema200: 1.080,
          support: 1.070,
          resistance: 1.100
        )
      end

      summary = described_class.new(symbol: "EURUSD").call

      expect(summary[:symbol]).to eq("EURUSD")
      expect(summary[:timeframes]["H4"][:trend]).to eq("bullish")
    end
  end
end
