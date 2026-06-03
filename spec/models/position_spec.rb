require "rails_helper"

RSpec.describe Position, type: :model do
  def unique_ticket
    "pos-#{SecureRandom.hex(8)}"
  end

  def build_order(status: :triggered)
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

  describe "associations" do
    it "has many execution audit logs" do
      order = build_order
      position = described_class.create!(
        order: order,
        ticket: unique_ticket,
        symbol: "XAUUSD",
        action: "BUY",
        entry_price: 3350,
        stop_loss: 3335,
        take_profit: 3380,
        opened_at: Time.current,
        status: :open
      )

      log = ExecutionAuditLog.create!(
        order: order,
        position: position,
        source: "position_updates",
        event_status: "open",
        ticket: position.ticket,
        payload: { "status" => "open" }
      )

      expect(position.execution_audit_logs).to include(log)
    end
  end

  describe "status enum" do
    it "defines open, closed, and cancelled statuses" do
      expect(described_class.statuses.keys).to match_array(%w[open closed cancelled])
    end
  end

  describe "associations" do
    it "belongs to an order" do
      order = build_order
      position = described_class.new(
        order: order,
        ticket: unique_ticket,
        symbol: "XAUUSD",
        action: "BUY",
        entry_price: 3350.50,
        stop_loss: 3335,
        take_profit: 3380,
        opened_at: Time.current
      )

      expect(position.order).to eq(order)
    end
  end

  describe "validations" do
    let(:order) { build_order }

    let(:valid_attributes) do
      {
        order: order,
        ticket: unique_ticket,
        symbol: "XAUUSD",
        action: "BUY",
        entry_price: 3350.50,
        stop_loss: 3335,
        take_profit: 3380,
        opened_at: Time.current
      }
    end

    it "is valid when open" do
      expect(described_class.new(valid_attributes)).to be_valid
    end

    it "allows profit_loss" do
      position = described_class.new(valid_attributes.merge(profit_loss: -12.5))

      expect(position).to be_valid
    end

    it "requires closed_at when closed" do
      position = described_class.new(valid_attributes.merge(status: :closed))

      expect(position).not_to be_valid
      expect(position.errors[:closed_at]).to include("can't be blank")
    end
  end
end
