require "rails_helper"

RSpec.describe TradeSignal, type: :model do
  describe "ACTIONS" do
    it "defines allowed actions" do
      expect(described_class::ACTIONS).to eq(%w[BUY SELL WAIT])
    end
  end

  describe "associations" do
    it "belongs to a market snapshot" do
      snapshot = MarketSnapshot.create!(
        symbol: "XAUUSD",
        timeframe: "H4",
        price: 4448.87
      )
      signal = described_class.new(
        market_snapshot: snapshot,
        symbol: "XAUUSD",
        action: "WAIT",
        confidence: 0
      )

      expect(signal.market_snapshot).to eq(snapshot)
    end

    it "is destroyed when its market snapshot is destroyed" do
      snapshot = MarketSnapshot.create!(
        symbol: "XAUUSD",
        timeframe: "H4",
        price: 4448.87,
        rsi: 36.97,
        ema50: 4483.80,
        ema200: 4506.55,
        support: 4438.85,
        resistance: 4496.63
      )
      described_class.create!(
        market_snapshot: snapshot,
        symbol: "XAUUSD",
        action: "WAIT",
        confidence: 0,
        timeframe: "H4"
      )

      expect { snapshot.destroy }.to change(described_class, :count).by(-1)
    end
  end

  describe "validations" do
    let(:market_snapshot) do
      MarketSnapshot.create!(
        symbol: "XAUUSD",
        timeframe: "H4",
        price: 4448.87,
        rsi: 36.97,
        ema50: 4483.80,
        ema200: 4506.55,
        support: 4438.85,
        resistance: 4496.63
      )
    end

    let(:valid_attributes) do
      {
        market_snapshot: market_snapshot,
        symbol: "XAUUSD",
        action: "WAIT",
        confidence: 75,
        timeframe: "H4",
        reason: "No edge",
        expires_at: 1.hour.from_now
      }
    end

    it "is valid with required attributes" do
      signal = described_class.new(valid_attributes)

      expect(signal).to be_valid
    end

    it "requires symbol" do
      signal = described_class.new(valid_attributes.except(:symbol))

      expect(signal).not_to be_valid
      expect(signal.errors[:symbol]).to include("can't be blank")
    end

    it "requires action" do
      signal = described_class.new(valid_attributes.except(:action))

      expect(signal).not_to be_valid
      expect(signal.errors[:action]).to include("can't be blank")
    end

    it "requires confidence" do
      signal = described_class.new(valid_attributes.except(:confidence))

      expect(signal).not_to be_valid
      expect(signal.errors[:confidence]).to include("can't be blank")
    end

    it "requires confidence between 0 and 100" do
      signal = described_class.new(valid_attributes.merge(confidence: 101))

      expect(signal).not_to be_valid
      expect(signal.errors[:confidence]).to be_present
    end

    it "requires a market snapshot" do
      signal = described_class.new(valid_attributes.except(:market_snapshot))

      expect(signal).not_to be_valid
      expect(signal.errors[:market_snapshot]).to include("must exist")
    end

    %w[BUY SELL WAIT].each do |action|
      it "allows action #{action}" do
        signal = described_class.new(valid_attributes.merge(action: action))

        expect(signal).to be_valid
      end
    end

    it "rejects invalid actions" do
      signal = described_class.new(valid_attributes.merge(action: "HOLD"))

      expect(signal).not_to be_valid
      expect(signal.errors[:action]).to include("is not included in the list")
    end
  end

  describe "persistence" do
    let(:market_snapshot) do
      MarketSnapshot.create!(
        symbol: "XAUUSD",
        timeframe: "H4",
        price: 4448.87,
        rsi: 36.97,
        ema50: 4483.80,
        ema200: 4506.55,
        support: 4438.85,
        resistance: 4496.63
      )
    end

    it "stores all columns" do
      expires_at = Time.zone.parse("2026-06-04 12:00:00")
      signal = described_class.create!(
        market_snapshot: market_snapshot,
        symbol: "XAUUSD",
        action: "BUY",
        confidence: 82,
        timeframe: "H4",
        reason: "RSI oversold, above support",
        expires_at: expires_at
      )

      signal.reload
      expect(signal.market_snapshot).to eq(market_snapshot)
      expect(signal.symbol).to eq("XAUUSD")
      expect(signal.action).to eq("BUY")
      expect(signal.confidence).to eq(82)
      expect(signal.timeframe).to eq("H4")
      expect(signal.reason).to eq("RSI oversold, above support")
      expect(signal.expires_at).to be_within(1.second).of(expires_at)
    end

    it "allows optional reason, timeframe, and expires_at" do
      signal = described_class.create!(
        market_snapshot: market_snapshot,
        symbol: "XAUUSD",
        action: "WAIT",
        confidence: 0
      )

      expect(signal.reason).to be_nil
      expect(signal.timeframe).to be_nil
      expect(signal.expires_at).to be_nil
    end
  end
end
