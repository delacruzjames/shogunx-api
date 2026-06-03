require "rails_helper"

RSpec.describe PositionMonitoringJob, type: :job do
  def create_open_position
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
      status: :triggered
    )

    Position.create!(
      order: order,
      ticket: "monitor-#{SecureRandom.hex(4)}",
      symbol: "XAUUSD",
      action: "BUY",
      entry_price: 3350,
      stop_loss: 3335,
      take_profit: 3380,
      opened_at: Time.current
    )
  end

  describe "#perform" do
    it "runs without error when there are no open positions" do
      expect { described_class.perform_now }.not_to raise_error
    end

    it "processes all open positions without error" do
      create_open_position
      create_open_position

      expect { described_class.perform_now }.not_to raise_error
      expect(Position.open_positions.count).to eq(2)
    end
  end
end
