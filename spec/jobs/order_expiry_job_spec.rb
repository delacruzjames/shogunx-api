require "rails_helper"

RSpec.describe OrderExpiryJob, type: :job do
  def create_pending_order(expires_at:, status: "pending")
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
      status: status,
      expires_at: expires_at
    )
  end

  describe "#perform" do
    it "expires pending orders past expires_at" do
      order = create_pending_order(expires_at: 1.hour.ago)

      described_class.perform_now

      expect(order.reload.status).to eq("expired")
    end

    it "leaves pending orders that have not expired" do
      order = create_pending_order(expires_at: 1.hour.from_now)

      described_class.perform_now

      expect(order.reload.status).to eq("pending")
    end

    it "leaves pending orders without expires_at" do
      order = create_pending_order(expires_at: nil)

      described_class.perform_now

      expect(order.reload.status).to eq("pending")
    end

    it "does not change non-pending orders" do
      order = create_pending_order(expires_at: 1.hour.ago, status: "placed")

      described_class.perform_now

      expect(order.reload.status).to eq("placed")
    end

    it "expires multiple pending orders in one run" do
      first = create_pending_order(expires_at: 2.hours.ago)
      second = create_pending_order(expires_at: 30.minutes.ago)
      active = create_pending_order(expires_at: 1.hour.from_now)

      described_class.perform_now

      expect(first.reload.status).to eq("expired")
      expect(second.reload.status).to eq("expired")
      expect(active.reload.status).to eq("pending")
    end
  end
end
