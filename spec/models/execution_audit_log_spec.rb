require "rails_helper"

RSpec.describe ExecutionAuditLog, type: :model do
  def create_order
    snapshot = MarketSnapshot.create!(
      symbol: "XAUUSD",
      timeframe: "H4",
      price: 3350
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
      status: :placed,
      ticket: "987654"
    )
  end

  describe "validations" do
    it "is valid with an order and required attributes" do
      order = create_order

      log = described_class.new(
        order: order,
        source: "order_updates",
        event_status: "placed",
        ticket: "987654",
        payload: { "status" => "placed" }
      )

      expect(log).to be_valid
    end

    it "requires a supported source" do
      log = described_class.new(
        source: "mt4",
        event_status: "placed",
        payload: {}
      )

      expect(log).not_to be_valid
      expect(log.errors[:source]).to be_present
    end

    it "requires an order or position" do
      log = described_class.new(
        source: "order_updates",
        event_status: "placed",
        payload: { "status" => "placed" }
      )

      expect(log).not_to be_valid
      expect(log.errors[:base]).to include("must belong to an order or position")
    end
  end

  describe "associations" do
    it "belongs to an order" do
      order = create_order
      log = described_class.create!(
        order: order,
        source: "order_updates",
        event_status: "placed",
        ticket: "987654",
        payload: { "status" => "placed" }
      )

      expect(order.execution_audit_logs).to include(log)
    end
  end
end
