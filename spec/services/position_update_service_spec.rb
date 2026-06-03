require "rails_helper"

RSpec.describe PositionUpdateService do
  def create_order(status: :pending)
    snapshot = MarketSnapshot.create!(
      symbol: "XAUUSD",
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
      symbol: "XAUUSD",
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
      status: status
    )
  end

  describe "#call" do
    it "opens a position using entry_price from MT4 and records audit" do
      order = create_order

      result = described_class.new(
        order_id: order.id,
        ticket: "987654",
        status: "open",
        entry_price: 3350.50
      ).call

      expect(result).to be_success
      expect(result.position.status).to eq("open")
      expect(result.position.entry_price).to eq(3350.50)
      expect(result.audit_log.source).to eq("position_updates")
      expect(order.reload.status).to eq("triggered")
    end

    it "closes a position and records trade performance" do
      order = create_order
      described_class.new(
        order_id: order.id,
        ticket: "987654",
        status: "open",
        entry_price: 3350.50
      ).call

      result = described_class.new(
        order_id: order.id,
        ticket: "987654",
        status: "closed",
        profit_loss: 125.50
      ).call

      expect(result).to be_success
      expect(result.position.status).to eq("closed")
      expect(result.position.profit_loss).to eq(125.50)
      expect(order.reload.status).to eq("closed")
      expect(TradePerformance.count).to eq(1)
    end

    it "skips audit when audit: false" do
      order = create_order

      expect {
        described_class.new(
          { order_id: order.id, ticket: "987654", status: "open", entry_price: 3350.50 },
          audit: false
        ).call
      }.not_to change(ExecutionAuditLog, :count)
    end

    it "returns an error when closing without profit_loss" do
      order = create_order
      described_class.new(
        order_id: order.id,
        ticket: "987654",
        status: "open",
        entry_price: 3350.50
      ).call

      result = described_class.new(
        order_id: order.id,
        ticket: "987654",
        status: "closed"
      ).call

      expect(result).not_to be_success
      expect(result.errors).to include("Profit/loss is required")
    end

    it "returns an error when the order is missing" do
      result = described_class.new(
        order_id: 0,
        ticket: "987654",
        status: "open",
        entry_price: 3350.50
      ).call

      expect(result).not_to be_success
      expect(result.errors).to include("Order not found")
    end
  end
end
