require "rails_helper"

RSpec.describe OrderStatusSyncService do
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
    it "updates order status to placed with ticket and audit log" do
      order = create_order

      result = described_class.new(order_id: order.id, status: "placed", ticket: "987654").call

      expect(result).to be_success
      expect(order.reload.status).to eq("placed")
      expect(order.ticket).to eq("987654")
      expect(result.audit_log.source).to eq("order_updates")
      expect(result.audit_log.event_status).to eq("placed")
    end

    it "updates order to triggered without creating a position" do
      order = create_order(status: :placed)

      result = described_class.new(
        order_id: order.id,
        status: "triggered",
        ticket: "987654"
      ).call

      expect(result).to be_success
      expect(order.reload.status).to eq("triggered")
      expect(order.position).to be_nil
    end

    it "closes the order and open position with profit_loss" do
      order = create_order(status: :triggered)
      Position.create!(
        order: order,
        ticket: "987654",
        symbol: "XAUUSD",
        action: "BUY",
        entry_price: 3350,
        stop_loss: 3335,
        take_profit: 3380,
        opened_at: 1.hour.ago,
        status: :open
      )

      result = described_class.new(
        order_id: order.id,
        status: "closed",
        ticket: "987654",
        profit_loss: 125.50
      ).call

      expect(result).to be_success
      expect(order.reload.status).to eq("closed")
      expect(order.position.reload.status).to eq("closed")
      expect(order.position.profit_loss).to eq(125.50)
      expect(TradePerformance.count).to eq(1)
      expect(ExecutionAuditLog.where(source: "order_updates", event_status: "closed").count).to eq(1)
    end

    it "returns an error when closing without profit_loss" do
      order = create_order(status: :triggered)

      result = described_class.new(
        order_id: order.id,
        status: "closed",
        ticket: "987654"
      ).call

      expect(result).not_to be_success
      expect(result.errors).to include("Profit/loss is required")
    end

    it "returns an error when the order is missing" do
      result = described_class.new(order_id: 0, status: "placed", ticket: "1").call

      expect(result).not_to be_success
      expect(result.errors).to include("Order not found")
    end

    it "returns an error for unsupported statuses" do
      order = create_order

      result = described_class.new(order_id: order.id, status: "pending", ticket: "1").call

      expect(result).not_to be_success
      expect(result.errors).to include("Unsupported order status")
    end
  end
end
