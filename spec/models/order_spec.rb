require "rails_helper"

RSpec.describe Order, type: :model do
  def build_trade_signal(action: "BUY")
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

    TradeSignal.create!(
      market_snapshot: snapshot,
      symbol: "XAUUSD",
      action: action,
      confidence: 75,
      timeframe: "H4"
    )
  end

  describe "status enum" do
    it "defines all valid statuses" do
      expect(described_class.statuses.keys).to match_array(
        %w[pending placed triggered closed cancelled expired]
      )
    end
  end

  describe "associations" do
    it "belongs to a trade signal" do
      trade_signal = build_trade_signal
      order = described_class.new(
        trade_signal: trade_signal,
        action: "BUY",
        entry_type: "BUY_LIMIT",
        entry_price: 3350,
        stop_loss: 3335,
        take_profit: 3380,
        risk_reward: 2.0,
        status: :pending
      )

      expect(order.trade_signal).to eq(trade_signal)
    end

    it "has many execution audit logs" do
      trade_signal = build_trade_signal
      order = described_class.create!(
        trade_signal: trade_signal,
        action: "BUY",
        entry_type: "BUY_LIMIT",
        entry_price: 3350,
        stop_loss: 3335,
        take_profit: 3380,
        risk_reward: 2.0,
        status: :placed
      )

      log = ExecutionAuditLog.create!(
        order: order,
        source: "order_updates",
        event_status: "placed",
        ticket: "1",
        payload: { "status" => "placed" }
      )

      expect(order.execution_audit_logs).to include(log)
    end

    it "allows multiple orders per trade signal" do
      trade_signal = build_trade_signal

      2.times do
        described_class.create!(
          trade_signal: trade_signal,
          action: "BUY",
          entry_type: "BUY_LIMIT",
          entry_price: 3350,
          stop_loss: 3335,
          take_profit: 3380,
          risk_reward: 2.0
        )
      end

      expect(trade_signal.orders.count).to eq(2)
    end
  end

  describe "validations" do
    let(:trade_signal) { build_trade_signal }

    let(:valid_attributes) do
      {
        trade_signal: trade_signal,
        action: "BUY",
        entry_type: "BUY_LIMIT",
        entry_price: 3350,
        stop_loss: 3335,
        take_profit: 3380,
        risk_reward: 2.0,
        expires_at: 1.day.from_now
      }
    end

    it "is valid with required attributes" do
      order = described_class.new(valid_attributes)

      expect(order).to be_valid
    end

    it "defaults status to pending" do
      order = described_class.create!(valid_attributes)

      expect(order.status).to eq("pending")
    end

    it "requires a trade signal" do
      order = described_class.new(valid_attributes.except(:trade_signal))

      expect(order).not_to be_valid
      expect(order.errors[:trade_signal]).to include("must exist")
    end

    it "requires risk_reward" do
      order = described_class.new(valid_attributes.except(:risk_reward))

      expect(order).not_to be_valid
      expect(order.errors[:risk_reward]).to include("can't be blank")
    end

    it "rejects invalid statuses" do
      order = described_class.new(valid_attributes)
      order.status = "open"

      expect(order).not_to be_valid
      expect(order.errors[:status]).to be_present
    end

    it "requires entry_type matching action" do
      order = described_class.new(valid_attributes.merge(entry_type: "SELL_LIMIT"))

      expect(order).not_to be_valid
      expect(order.errors[:entry_type]).to include("must be BUY_LIMIT for action BUY")
    end
  end

  describe "persistence" do
    it "stores all columns with decimal precision" do
      trade_signal = build_trade_signal(action: "SELL")
      opened_at = Time.zone.parse("2026-06-04 08:00:00")
      closed_at = Time.zone.parse("2026-06-04 16:00:00")
      expires_at = Time.zone.parse("2026-06-05 08:00:00")

      order = described_class.create!(
        trade_signal: trade_signal,
        action: "SELL",
        entry_type: "SELL_LIMIT",
        entry_price: 3380.12345,
        stop_loss: 3395.54321,
        take_profit: 3350.11111,
        risk_reward: 2.15,
        status: :placed,
        opened_at: opened_at,
        closed_at: closed_at,
        expires_at: expires_at
      )

      order.reload
      expect(order.entry_price).to eq(3380.12345)
      expect(order.stop_loss).to eq(3395.54321)
      expect(order.take_profit).to eq(3350.11111)
      expect(order.risk_reward).to eq(2.15)
      expect(order.status).to eq("placed")
    end
  end
end
