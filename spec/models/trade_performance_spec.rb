require "rails_helper"

RSpec.describe TradePerformance, type: :model do
  def build_closed_position
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
    order = Order.create!(
      trade_signal: trade_signal,
      action: "BUY",
      entry_type: "BUY_LIMIT",
      entry_price: 3350,
      stop_loss: 3335,
      take_profit: 3380,
      risk_reward: 2.0,
      status: :closed
    )

    Position.create!(
      order: order,
      ticket: "perf-#{SecureRandom.hex(4)}",
      symbol: "XAUUSD",
      action: "BUY",
      entry_price: 3350.50,
      stop_loss: 3335,
      take_profit: 3380,
      status: :closed,
      profit_loss: 25.5,
      opened_at: 2.hours.ago,
      closed_at: Time.current
    )
  end

  describe "validations" do
    it "is valid with required attributes" do
      position = build_closed_position

      record = described_class.new(
        position: position,
        symbol: position.symbol,
        action: position.action,
        entry_price: position.entry_price,
        exit_price: 3375.50,
        profit_loss: 25.5,
        opened_at: position.opened_at,
        closed_at: position.closed_at
      )

      expect(record).to be_valid
    end

    it "requires a unique position" do
      position = build_closed_position
      described_class.create!(
        position: position,
        symbol: position.symbol,
        action: position.action,
        entry_price: position.entry_price,
        exit_price: 3375.50,
        profit_loss: 25.5,
        opened_at: position.opened_at,
        closed_at: position.closed_at
      )

      duplicate = described_class.new(
        position: position,
        symbol: position.symbol,
        action: position.action,
        entry_price: position.entry_price,
        exit_price: 3376.00,
        profit_loss: 30.0,
        opened_at: position.opened_at,
        closed_at: position.closed_at
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:position_id]).to include("has already been taken")
    end
  end
end
