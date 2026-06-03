require "rails_helper"

RSpec.describe TradeSignal, type: :model do
  describe "ACTIONS" do
    it "defines allowed actions" do
      expect(described_class::ACTIONS).to eq(%w[BUY SELL WAIT])
    end
  end

  describe "validations" do
    let(:valid_attributes) do
      {
        symbol: "EURUSD",
        action: "WAIT",
        confidence: 75,
        timeframe: "H1",
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

    it "requires timeframe" do
      signal = described_class.new(valid_attributes.except(:timeframe))

      expect(signal).not_to be_valid
      expect(signal.errors[:timeframe]).to include("can't be blank")
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
    it "stores all columns" do
      expires_at = Time.zone.parse("2026-06-04 12:00:00")
      signal = described_class.create!(
        symbol: "XAUUSD",
        action: "BUY",
        confidence: 82,
        timeframe: "H4",
        reason: "RSI oversold, above support",
        expires_at: expires_at
      )

      signal.reload
      expect(signal.symbol).to eq("XAUUSD")
      expect(signal.action).to eq("BUY")
      expect(signal.confidence).to eq(82)
      expect(signal.timeframe).to eq("H4")
      expect(signal.reason).to eq("RSI oversold, above support")
      expect(signal.expires_at).to be_within(1.second).of(expires_at)
    end

    it "allows optional reason and expires_at" do
      signal = described_class.create!(
        symbol: "EURUSD",
        action: "WAIT",
        confidence: 0,
        timeframe: "H1"
      )

      expect(signal.reason).to be_nil
      expect(signal.expires_at).to be_nil
    end
  end
end
