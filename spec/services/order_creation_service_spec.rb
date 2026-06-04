require "rails_helper"

RSpec.describe OrderCreationService do
  def build_trade_signal(action:, support: 3350.0, resistance: 3380.0, price: 3350, expires_at: nil)
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
      reason: "Test signal",
      expires_at: expires_at
    )
  end

  describe "#call" do
    it "returns nil for WAIT signals without creating an order" do
      signal = build_trade_signal(action: "WAIT")

      expect {
        expect(described_class.new(signal).call).to be_nil
      }.not_to change(Order, :count)
    end

    it "returns nil when no plan can be built" do
      signal = build_trade_signal(action: "BUY", support: 3380.0, resistance: 3350.0)

      expect(described_class.new(signal).call).to be_nil
    end

    it "creates a pending BUY order from the plan" do
      signal = build_trade_signal(action: "BUY", price: 3360)
      expires_at = 1.day.from_now
      signal.update!(expires_at: expires_at)

      order = nil
      expect {
        order = described_class.new(signal).call
      }.to change(Order, :count).by(3)

      expect(order).to be_persisted
      expect(order.trade_signal).to eq(signal)
      expect(order.action).to eq("BUY")
      expect(order.entry_type).to eq("BUY_LIMIT")
      expect(order.entry_price).to eq(3350)
      expect(order.stop_loss).to eq(3335)
      expect(order.take_profit).to eq(3370)
      expect(order.tp_leg).to eq(1)
      expect(order.risk_reward).to be > 0
      expect(order.status).to eq("pending")
      expect(order.expires_at).to be_within(1.second).of(expires_at)
      expect(order.opened_at).to be_nil
      expect(order.closed_at).to be_nil
    end

    it "creates a pending SELL order from the plan" do
      signal = build_trade_signal(action: "SELL")

      order = described_class.new(signal).call

      expect(order.action).to eq("SELL")
      expect(order.entry_type).to eq("SELL_LIMIT")
      expect(order.entry_price).to eq(3380)
      expect(order.stop_loss).to eq(3395)
      expect(order.take_profit).to eq(3360)
      expect(order.tp_leg).to eq(1)
      expect(order.status).to eq("pending")
    end

    it "delegates to OrderPlanService#create_order!" do
      signal = build_trade_signal(action: "BUY")
      plan_service = instance_double(OrderPlanService, create_order!: :created_order)

      result = described_class.new(signal, plan_service: plan_service).call

      expect(result).to eq(:created_order)
    end
  end
end
