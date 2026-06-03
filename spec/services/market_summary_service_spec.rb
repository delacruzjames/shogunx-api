require "rails_helper"

RSpec.describe MarketSummaryService do
  describe "#call" do
    it "returns an empty summary when no XAUUSD snapshots exist" do
      summary = described_class.new.call

      expect(summary).to eq(
        symbol: "XAUUSD",
        current_price: nil,
        current_rsi: nil,
        current_ema50: nil,
        current_ema200: nil,
        support: nil,
        resistance: nil,
        trend: "neutral",
        average_rsi: nil,
        snapshot_count: 0
      )
    end

    it "summarizes the latest snapshot and trend" do
      MarketSnapshot.create!(
        symbol: "XAUUSD",
        timeframe: "H4",
        price: 4450.50,
        rsi: 42.5,
        ema50: 4480.00,
        ema200: 4500.00,
        support: 4430.00,
        resistance: 4495.00,
        created_at: 2.hours.ago
      )
      MarketSnapshot.create!(
        symbol: "XAUUSD",
        timeframe: "H4",
        price: 4448.87,
        rsi: 36.97,
        ema50: 4483.80,
        ema200: 4506.55,
        support: 4438.85,
        resistance: 4496.63,
        created_at: 1.hour.ago
      )

      summary = described_class.new.call

      expect(summary[:symbol]).to eq("XAUUSD")
      expect(summary[:current_price]).to eq(4448.87)
      expect(summary[:current_rsi]).to eq(36.97)
      expect(summary[:current_ema50]).to eq(4483.80)
      expect(summary[:current_ema200]).to eq(4506.55)
      expect(summary[:support]).to eq(4438.85)
      expect(summary[:resistance]).to eq(4496.63)
      expect(summary[:trend]).to eq("bearish")
      expect(summary[:average_rsi]).to be_within(0.01).of(39.735)
      expect(summary[:snapshot_count]).to eq(2)
    end

    it "returns bullish when ema50 is above ema200" do
      MarketSnapshot.create!(
        symbol: "XAUUSD",
        timeframe: "H4",
        price: 4500,
        rsi: 60,
        ema50: 4510,
        ema200: 4490,
        support: 4480,
        resistance: 4520
      )

      expect(described_class.new.call[:trend]).to eq("bullish")
    end

    it "returns neutral when ema50 equals ema200" do
      MarketSnapshot.create!(
        symbol: "XAUUSD",
        timeframe: "H4",
        price: 4500,
        rsi: 50,
        ema50: 4500,
        ema200: 4500,
        support: 4480,
        resistance: 4520
      )

      expect(described_class.new.call[:trend]).to eq("neutral")
    end

    it "loads only the latest 10 XAUUSD snapshots for averages" do
      12.times do |i|
        MarketSnapshot.create!(
          symbol: "XAUUSD",
          timeframe: "H4",
          price: 4400 + i,
          rsi: 10 * i,
          ema50: 4480,
          ema200: 4500,
          support: 4430,
          resistance: 4490,
          created_at: i.hours.ago
        )
      end

      MarketSnapshot.create!(
        symbol: "EURUSD",
        timeframe: "H1",
        price: 1.085,
        rsi: 99,
        ema50: 1.084,
        ema200: 1.082,
        support: 1.080,
        resistance: 1.090
      )

      summary = described_class.new.call

      expect(summary[:snapshot_count]).to eq(10)
      expect(summary[:current_price]).to eq(4400)
      expect(summary[:average_rsi]).to eq(45.0)
    end

    it "allows a custom symbol" do
      MarketSnapshot.create!(
        symbol: "EURUSD",
        timeframe: "H1",
        price: 1.085,
        rsi: 55,
        ema50: 1.090,
        ema200: 1.080,
        support: 1.070,
        resistance: 1.100
      )

      summary = described_class.new(symbol: "EURUSD").call

      expect(summary[:symbol]).to eq("EURUSD")
      expect(summary[:trend]).to eq("bullish")
      expect(summary[:snapshot_count]).to eq(1)
    end
  end
end
