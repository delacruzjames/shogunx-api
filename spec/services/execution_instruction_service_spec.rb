require "rails_helper"

RSpec.describe ExecutionInstructionService do
  def create_pending_order(created_at: Time.current, status: :pending, symbol: "XAUUSD", tp_leg: 1)
    snapshot = MarketSnapshot.create!(
      symbol: symbol,
      timeframe: "H4",
      price: 3350,
      rsi: 60,
      ema50: 3360,
      ema200: 3340,
      support: 3350,
      resistance: 3380
    )
    trade_signal = TradeSignal.create!(
      market_snapshot: snapshot,
      symbol: symbol,
      action: "BUY",
      confidence: 75,
      timeframe: "H4"
    )

    Order.create!(
      trade_signal: trade_signal,
      action: "BUY",
      entry_type: "BUY_LIMIT",
      entry_price: 3350,
      stop_loss: 3335,
      take_profit: 3380,
      risk_reward: 2.0,
      tp_leg: tp_leg,
      status: status,
      created_at: created_at
    )
  end

  describe "#call" do
    it "returns hold when no pending order exists" do
      result = described_class.new.call

      expect(result).to eq(
        order: {
          action: "hold",
          reason: "no pending order available"
        }
      )
    end

    it "returns executable instruction for the oldest pending order (TP leg queue)" do
      oldest = create_pending_order(created_at: 2.hours.ago, tp_leg: 1)
      create_pending_order(created_at: 1.hour.ago, tp_leg: 2)

      result = described_class.new.call

      expect(result[:order]).to include(
        action: "BUY_LIMIT",
        order_id: oldest.id,
        symbol: "XAUUSD",
        entry_price: oldest.entry_price,
        stop_loss: oldest.stop_loss,
        take_profit: oldest.take_profit,
        reason: "pending order ready for MT4 execution"
      )
    end

    it "uses a specific order when provided" do
      order = create_pending_order

      result = described_class.new(order: order).call

      expect(result[:order][:order_id]).to eq(order.id)
    end

    it "returns SELL_LIMIT instructions for sell orders" do
      snapshot = MarketSnapshot.create!(
        symbol: "XAUUSD",
        timeframe: "H4",
        price: 3350,
        rsi: 40,
        ema50: 3340,
        ema200: 3360,
        support: 3350,
        resistance: 3380
      )
      trade_signal = TradeSignal.create!(
        market_snapshot: snapshot,
        symbol: "XAUUSD",
        action: "SELL",
        confidence: 75,
        timeframe: "H4"
      )
      order = Order.create!(
        trade_signal: trade_signal,
        action: "SELL",
        entry_type: "SELL_LIMIT",
        entry_price: 3380,
        stop_loss: 3395,
        take_profit: 3350,
        risk_reward: 2.0,
        status: :pending
      )

      result = described_class.new(order: order).call

      expect(result[:order]).to include(
        action: "SELL_LIMIT",
        order_id: order.id,
        symbol: "XAUUSD",
        entry_price: order.entry_price,
        stop_loss: order.stop_loss,
        take_profit: order.take_profit
      )
    end

    it "ignores non-pending orders when resolving the latest" do
      create_pending_order(status: :placed)

      result = described_class.new.call

      expect(result[:order][:action]).to eq("hold")
    end
  end

  describe "#call with execution format" do
    it "returns a flat HOLD payload" do
      result = described_class.new(format: :execution).call

      expect(result).to eq(
        action: "HOLD",
        reason: "No approved trade available"
      )
    end

    it "returns a flat executable payload with expires_at" do
      expires_at = Time.zone.parse("2026-06-03T16:00:00Z")
      order = create_pending_order
      order.update!(expires_at: expires_at)

      result = described_class.new(format: :execution).call

      expect(result).to eq(
        action: "BUY_LIMIT",
        order_id: order.id,
        symbol: "XAUUSD",
        entry_price: order.entry_price,
        stop_loss: order.stop_loss,
        take_profit: order.take_profit,
        expires_at: expires_at.iso8601
      )
    end
  end
end
