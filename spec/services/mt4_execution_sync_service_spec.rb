require "rails_helper"

RSpec.describe Mt4ExecutionSyncService do
  def create_order
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
      status: :pending
    )
  end

  describe "MT4 execution feedback loop" do
    it "syncs the full lifecycle from pending to closed with P/L" do
      order = create_order
      sync = described_class.new(order)

      expect(sync.record_placed!(ticket: "987654")).to be_success
      expect(sync.lifecycle_state).to include(
        order_status: "placed",
        ticket: "987654",
        position_status: nil
      )

      expect(sync.record_triggered!(ticket: "987654")).to be_success
      expect(sync.lifecycle_state).to include(
        order_status: "triggered",
        position_status: nil
      )

      expect(sync.record_open!(ticket: "987654", entry_price: 3350.50)).to be_success
      expect(sync.lifecycle_state).to include(
        order_status: "triggered",
        position_status: "open"
      )

      expect(sync.record_closed!(ticket: "987654", profit_loss: 125.50)).to be_success
      state = sync.lifecycle_state
      expect(state).to include(
        order_status: "closed",
        position_status: "closed",
        profit_loss: 125.50,
        trade_performance_recorded: true
      )
      expect(TradePerformance.count).to eq(1)
    end
  end
end
