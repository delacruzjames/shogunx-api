require "rails_helper"

RSpec.describe ExecutionAuditLogService do
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
      status: :placed
    )
  end

  describe "#record!" do
    it "persists an audit log with ticket and profit_loss" do
      order = create_order

      log = described_class.new(
        source: "position_updates",
        params: {
          order_id: order.id,
          ticket: 987654,
          status: "closed",
          profit_loss: 125.50
        },
        order: order
      ).record!

      expect(log).to be_persisted
      expect(log.source).to eq("position_updates")
      expect(log.event_status).to eq("closed")
      expect(log.ticket).to eq("987654")
      expect(log.profit_loss).to eq(125.50)
      expect(log.payload["status"]).to eq("closed")
    end
  end
end
