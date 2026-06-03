require "rails_helper"

RSpec.describe OpenaiAnalysisService do
  describe "#call" do
    it "returns the stub analysis without calling OpenAI" do
      result = described_class.new.call

      expect(result).to eq(
        action: "WAIT",
        confidence: 0,
        timeframe: "H4",
        reason: "Not implemented"
      )
    end
  end

  describe "#market_summary" do
    it "includes no snapshots when none exist for XAUUSD" do
      summary = described_class.new.market_summary

      expect(summary[:symbol]).to eq("XAUUSD")
      expect(summary[:snapshot_count]).to eq(0)
      expect(summary[:snapshots]).to eq([])
    end

    it "loads the latest 10 XAUUSD snapshots ordered newest first" do
      12.times do |i|
        MarketSnapshot.create!(
          symbol: "XAUUSD",
          timeframe: "H4",
          price: 4400 + i,
          rsi: 50,
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
        rsi: 50,
        ema50: 1.084,
        ema200: 1.082,
        support: 1.080,
        resistance: 1.090
      )

      service = described_class.new
      service.call
      summary = service.market_summary

      expect(summary[:snapshot_count]).to eq(10)
      expect(summary[:snapshots].size).to eq(10)
      expect(summary[:snapshots].map { |row| row[:price] }).to eq(
        (0..9).map { |i| BigDecimal((4400 + i).to_s) }
      )
      expect(summary[:snapshots].first).to include(
        :id,
        :timeframe,
        :price,
        :rsi,
        :ema50,
        :ema200,
        :support,
        :resistance,
        :captured_at
      )
    end

    it "allows a custom symbol" do
      MarketSnapshot.create!(
        symbol: "EURUSD",
        timeframe: "H1",
        price: 1.085,
        rsi: 55,
        ema50: 1.084,
        ema200: 1.082,
        support: 1.080,
        resistance: 1.090
      )

      summary = described_class.new(symbol: "EURUSD").market_summary

      expect(summary[:symbol]).to eq("EURUSD")
      expect(summary[:snapshot_count]).to eq(1)
    end
  end
end
