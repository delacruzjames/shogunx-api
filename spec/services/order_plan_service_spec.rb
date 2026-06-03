require "rails_helper"

RSpec.describe OrderPlanService do
  def build_trade_signal(action:, support: 3335.0, resistance: 3380.0, price: 3350.0)
    snapshot = MarketSnapshot.create!(
      symbol: "XAUUSD",
      timeframe: "H4",
      price: price,
      rsi: 60,
      ema50: 3360,
      ema200: 3340,
      support: support,
      resistance: resistance
    )

    TradeSignal.create!(
      market_snapshot: snapshot,
      symbol: "XAUUSD",
      action: action,
      confidence: 75,
      timeframe: "H4",
      reason: "Test signal"
    )
  end

  describe "#call" do
    it "returns nil for WAIT signals" do
      signal = build_trade_signal(action: "WAIT")

      expect(described_class.new(signal).call).to be_nil
    end

    it "builds a BUY limit plan near support with stop below and target at resistance" do
      signal = build_trade_signal(action: "BUY", support: 3350.0, resistance: 3380.0)

      plan = described_class.new(signal).call

      expect(plan).to eq(
        action: "BUY",
        entry_type: "BUY_LIMIT",
        entry_price: 3350.0,
        stop_loss: 3335.0,
        take_profit: 3380.0,
        risk_reward: 2.0
      )
    end

    it "builds a SELL limit plan near resistance with stop above and target at support" do
      signal = build_trade_signal(action: "SELL", support: 3350.0, resistance: 3380.0)

      plan = described_class.new(signal).call

      expect(plan).to eq(
        action: "SELL",
        entry_type: "SELL_LIMIT",
        entry_price: 3380.0,
        stop_loss: 3395.0,
        take_profit: 3350.0,
        risk_reward: 2.0
      )
    end

    it "returns nil when support and resistance are missing" do
      snapshot = MarketSnapshot.create!(
        symbol: "XAUUSD",
        timeframe: "H4",
        price: 3350,
        rsi: 60,
        ema50: 3360,
        ema200: 3340
      )
      signal = TradeSignal.create!(
        market_snapshot: snapshot,
        symbol: "XAUUSD",
        action: "BUY",
        confidence: 75
      )

      expect(described_class.new(signal).call).to be_nil
    end

    it "returns nil when support is not below resistance" do
      signal = build_trade_signal(action: "BUY", support: 3380.0, resistance: 3350.0)

      expect(described_class.new(signal).call).to be_nil
    end
  end

  describe "#create_order!" do
    it "returns nil for WAIT signals" do
      signal = build_trade_signal(action: "WAIT")

      expect {
        expect(described_class.new(signal).create_order!).to be_nil
      }.not_to change(Order, :count)
    end

    it "creates a pending order from the plan" do
      signal = build_trade_signal(action: "BUY", support: 3350.0, resistance: 3380.0)
      expires_at = 1.day.from_now
      signal.update!(expires_at: expires_at)

      order = nil
      expect {
        order = described_class.new(signal).create_order!
      }.to change(Order, :count).by(1)

      expect(order).to be_persisted
      expect(order.trade_signal).to eq(signal)
      expect(order.action).to eq("BUY")
      expect(order.entry_type).to eq("BUY_LIMIT")
      expect(order.entry_price).to eq(3350.0)
      expect(order.stop_loss).to eq(3335.0)
      expect(order.take_profit).to eq(3380.0)
      expect(order.risk_reward).to eq(2.0)
      expect(order.status).to eq("pending")
      expect(order.expires_at).to be_within(1.second).of(expires_at)
    end
  end
end
